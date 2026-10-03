// api/send-push.js
// -----------------------------------------------------------------------
// دالة خارجية واحدة (Vercel Serverless Function) مهمّتها الوحيدة: إرسال
// إشعار Push حقيقي (FCM) لمعلمة واحدة محددة، بعد إعادة التحقق الكامل من
// الصلاحية على الخادم — لا تثق هذه الدالة بأي شيء يُرسَل من التطبيق سوى
// idToken نفسه (يُتحقَّق منه عبر Firebase Admin SDK)، وتُعيد قراءة كل
// بيانات التفويض (الدور، المسجد، صاحبة المستند) مباشرة من Firestore.
//
// لماذا يجب أن تكون هذه الدالة خارج تطبيق Flutter نفسه (وخارج Firebase
// Cloud Functions أيضاً): إرسال Push إلى توكن جهاز محدد عبر FCM يتطلب
// بيانات اعتماد حساب خدمة (Service Account / Admin SDK) موثوقة تماماً —
// هذا شرط أمان من Google نفسها، وليس قراراً معمارياً. ووضع هذه الدالة على
// Vercel (بدل Cloud Functions) يُبقي مشروع Firebase بالكامل على خطة Spark
// المجانية، لأن Cloud Functions غير متاحة إطلاقاً على Spark وتتطلب الترقية
// لخطة Blaze.
//
// مبدأ عدم التكرار (idempotency): كل مستند إشعار يحمل حقل pushSent — إن
// كان true بالفعل، لا تُرسِل الدالة أي شيء وتُعيد فقط أنها تجاهلت الطلب.
//
// مبدأ "الرسالة لا تضيع أبداً": مستند الإشعار مكتوب أصلاً في Firestore من
// تطبيق Flutter نفسه قبل استدعاء هذه الدالة بالكامل (انظر
// NotificationService.sendCustomMessage) — فشل هذه الدالة أو تعطُّلها لا
// يعني ضياع الرسالة، فقط عدم وصول تنبيه فوري؛ ستظل المعلمة تراها داخل
// شاشة الإشعارات في التطبيق كالمعتاد.

const admin = require('firebase-admin');

// نُهيّئ Admin SDK مرة واحدة فقط لكل نسخة دالة تشغيلية (Vercel قد يُعيد
// استخدام نفس النسخة لعدة طلبات متتالية — تجنّباً لخطأ "already exists").
if (!admin.apps.length) {
  // .replace(/^﻿/, '') يُزيل حرف BOM غير المرئي الذي تُضيفه أحياناً
  // أدوات ويندوز (Notepad/PowerShell) في أول الملف عند نسخ/تمرير محتواه —
  // بدونه يفشل JSON.parse برسالة غامضة "Unexpected token '﻿'".
  const raw = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '')
    .replace(/^﻿/, '')
    .trim();
  if (!raw) {
    throw new Error(
      'متغيّر البيئة FIREBASE_SERVICE_ACCOUNT_JSON غير مضبوط. راجعي README.md.'
    );
  }
  const serviceAccount = JSON.parse(raw);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

// نطاقات الويب المسموح لها فعلياً باستدعاء هذه الدالة من المتصفح (CORS).
// حدّثي هذه القائمة إن أضفتِ نطاقاً مخصَّصاً لاحقاً (Custom Domain).
const ALLOWED_ORIGINS = [
  'https://daftar-alhalaqah.web.app',
  'https://daftar-alhalaqah.firebaseapp.com',
];

function applyCors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

module.exports = async function handler(req, res) {
  applyCors(req, res);

  // تطبيق أندرويد الأصلي (وليس PWA) لا يُطبَّق عليه CORS إطلاقاً (طلبات
  // HTTP خارج المتصفح) — هذا الفرع فقط لأجل طلبات "تمهيدية" (preflight)
  // يُرسلها المتصفح تلقائياً قبل POST من الويب.
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const { idToken, notificationId } = req.body || {};
  if (!idToken || !notificationId) {
    res.status(400).json({ error: 'missing_idToken_or_notificationId' });
    return;
  }

  // ------------------------------------------------------------------
  // 1) التحقق من هوية المُرسِلة (لا نثق بأي شيء آخر قادم من العميل)
  // ------------------------------------------------------------------
  let callerUid;
  try {
    const decoded = await auth.verifyIdToken(idToken);
    callerUid = decoded.uid;
  } catch (e) {
    res.status(401).json({ error: 'invalid_id_token' });
    return;
  }

  const callerSnap = await db.collection('users').doc(callerUid).get();
  if (!callerSnap.exists) {
    res.status(403).json({ error: 'caller_not_found' });
    return;
  }
  const caller = callerSnap.data();

  // ------------------------------------------------------------------
  // 2) قراءة مستند الإشعار نفسه — كل شيء بعد هذا يُبنى على ما هو مكتوب
  //    فعلاً في Firestore، وليس على ما يدّعيه الطلب.
  // ------------------------------------------------------------------
  const notifRef = db.collection('notifications').doc(notificationId);
  const notifSnap = await notifRef.get();
  if (!notifSnap.exists) {
    res.status(404).json({ error: 'notification_not_found' });
    return;
  }
  const notif = notifSnap.data();

  if (notif.pushSent === true) {
    // مبدأ عدم التكرار — طلب مكرر (إعادة محاولة من الشبكة مثلاً) يُتجاهَل بأمان.
    res.status(200).json({ skipped: true, reason: 'already_sent' });
    return;
  }

  if (notif.type !== 'custom_message') {
    // هذه الدالة مخصَّصة فقط لرسائل "إرسال رسالة للمعلمات" اليدوية — أي
    // نوع آخر (تقارير/نقل طالبة/المركز الصيفي...) مرفوض عمداً، لم تُفعَّل
    // لها دفعات Push بعد.
    res.status(400).json({ error: 'not_a_custom_message' });
    return;
  }

  // كل ما يلي مُغلَّف بـtry/catch واحد عمداً: أي خطأ غير متوقَّع (فهرس
  // Firestore ناقص، استثناء برمجي، إلخ) يجب أن يُسجَّل بوضوح في مستند
  // الإشعار نفسه (pushResult) بدل أن يختفي بصمت ويترك pushSent بلا قيمة
  // إطلاقاً — وهو بالضبط ما كان يحدث قبل هذا التعديل.
  try {
  // ------------------------------------------------------------------
  // 3) تحديد قائمة المستلِمات الفعلية + إعادة التحقق من صلاحية المُرسِلة
  //    على الخادم (بصرف النظر عمّا سمحت به قواعد أمان Firestore للعميل
  //    مسبقاً عند إنشاء المستند) — ثلاث حالات حسب ما كُتب في notif نفسه:
  //    أ) recipientUid محدَّد: معلمة واحدة بعينها.
  //    ب) targetMosqueId محدَّد بلا recipientUid: كل معلمات ذلك المسجد.
  //    ج) كلاهما غير محدَّد: كل معلمات كل المساجد (المشرفة العامة فقط).
  // ------------------------------------------------------------------
  const targetMosqueId = notif.targetMosqueId;
  const isGeneralSupervisor = caller.role === 'supervisor';
  const isAuthorizedMosqueSupervisor =
    caller.role === 'mosqueSupervisor' && caller.mosqueId === targetMosqueId;

  let recipientUids;

  if (notif.recipientUid) {
    // حالة (أ) — معلمة واحدة محددة، بنفس التحقق الأصلي تماماً.
    const recipientUid = notif.recipientUid;
    const recipientSnap = await db.collection('users').doc(recipientUid).get();
    if (!recipientSnap.exists) {
      res.status(404).json({ error: 'recipient_not_found' });
      return;
    }
    const recipient = recipientSnap.data();
    const recipientMatchesMosque = recipient.mosqueId === targetMosqueId;
    if (
      !recipientMatchesMosque ||
      !(isGeneralSupervisor || isAuthorizedMosqueSupervisor)
    ) {
      res.status(403).json({ error: 'not_authorized_for_this_recipient' });
      return;
    }
    recipientUids = [recipientUid];
  } else if (targetMosqueId) {
    // حالة (ب) — بث لكل معلمات مسجد واحد محدد.
    if (!(isGeneralSupervisor || isAuthorizedMosqueSupervisor)) {
      res.status(403).json({ error: 'not_authorized_for_this_mosque' });
      return;
    }
    // شرط مساواة واحد فقط على 'role' (مفهرس تلقائياً دائماً)، ثم تصفية
    // mosqueId في الذاكرة بدل شرط where ثانٍ — تفادياً لأي احتمال حاجة
    // لفهرس مركَّب (composite index) غير موجود بعد في المشروع، بنفس نهج
    // الحذر المتّبع في NotificationService.watchSupervisorNotifications.
    const teachersSnap = await db
      .collection('users')
      .where('role', '==', 'teacher')
      .get();
    recipientUids = teachersSnap.docs
      .filter((d) => d.data().mosqueId === targetMosqueId)
      .map((d) => d.id);
  } else {
    // حالة (ج) — بث لكل معلمات كل المساجد، للمشرفة العامة حصراً.
    if (!isGeneralSupervisor) {
      res.status(403).json({ error: 'not_authorized_for_global_broadcast' });
      return;
    }
    const teachersSnap = await db
      .collection('users')
      .where('role', '==', 'teacher')
      .get();
    recipientUids = teachersSnap.docs.map((d) => d.id);
  }

  if (recipientUids.length === 0) {
    await notifRef.update({
      pushSent: true,
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushResult: 'no_recipients',
    });
    res.status(200).json({ sent: false, reason: 'no_recipients' });
    return;
  }

  // ------------------------------------------------------------------
  // 4) جلب توكنات كل المستلِمات (قد يكون لكل واحدة أكثر من جهاز) — قراءة
  //    مستقلة لكل معلمة (بدل collectionGroup) لتبقى بنية البيانات والكود
  //    مطابقة تماماً لما هو مُختبَر فعلاً في حالة المعلمة الواحدة.
  // ------------------------------------------------------------------
  const tokenEntries = []; // { uid, token }[]
  await Promise.all(
    recipientUids.map(async (uid) => {
      const tokensSnap = await db
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .get();
      tokensSnap.docs.forEach((d) => tokenEntries.push({ uid, token: d.id }));
    })
  );

  if (tokenEntries.length === 0) {
    // لا يوجد جهاز مسجَّل لدى أي من المستلِمات بعد — ليس خطأً، الرسالة
    // محفوظة أصلاً في Firestore وستظهر عند فتح التطبيق كالمعتاد.
    await notifRef.update({
      pushSent: true,
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushResult: 'no_registered_device',
    });
    res.status(200).json({ sent: false, reason: 'no_registered_device' });
    return;
  }

  // FCM يسمح بحد أقصى 500 توكن لكل استدعاء sendEachForMulticast واحد —
  // نُقسّم إلى دفعات عند بث لعدد كبير من المعلمات (حالتا ب/ج أعلاه).
  const BATCH_SIZE = 500;
  const batches = [];
  for (let i = 0; i < tokenEntries.length; i += BATCH_SIZE) {
    batches.push(tokenEntries.slice(i, i + BATCH_SIZE));
  }

  const staleTokenCodes = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ]);
  const cleanupPromises = [];
  let totalSuccess = 0;
  let totalFailure = 0;

  for (const batch of batches) {
    const message = {
      tokens: batch.map((e) => e.token),
      notification: {
        title: notif.title,
        body: notif.body,
      },
      data: {
        notificationId,
        type: 'custom_message',
      },
      webpush: {
        fcmOptions: { link: '/' },
      },
    };

    let response;
    try {
      response = await messaging.sendEachForMulticast(message);
    } catch (e) {
      // فشل هذه الدفعة بالكامل — نُكمل بقية الدفعات إن وُجدت بدل إيقاف
      // كل شيء بسبب دفعة واحدة فاشلة.
      totalFailure += batch.length;
      continue;
    }

    totalSuccess += response.successCount;
    totalFailure += response.failureCount;

    response.responses.forEach((r, i) => {
      if (!r.success && r.error && staleTokenCodes.has(r.error.code)) {
        const { uid, token } = batch[i];
        cleanupPromises.push(
          db
            .collection('users')
            .doc(uid)
            .collection('fcmTokens')
            .doc(token)
            .delete()
            .catch(() => {})
        );
      }
    });
  }

  // ------------------------------------------------------------------
  // 5) تنظيف التوكنات الفاسدة/المنتهية (دوّار أو أُلغي تثبيت التطبيق)
  // ------------------------------------------------------------------
  await Promise.all(cleanupPromises);

  // ------------------------------------------------------------------
  // 6) تحديث مستند الإشعار (منع التكرار) + سجل إرسال منفصل للتدقيق
  // ------------------------------------------------------------------
  await notifRef.update({
    pushSent: true,
    pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
    pushResult: `${totalSuccess}/${tokenEntries.length}`,
  });

  await db.collection('notification_push_logs').add({
    notificationId,
    recipientUids,
    senderUid: callerUid,
    successCount: totalSuccess,
    failureCount: totalFailure,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  res.status(200).json({
    sent: true,
    recipientCount: recipientUids.length,
    successCount: totalSuccess,
    failureCount: totalFailure,
  });
  } catch (e) {
    // نسجّل الخطأ في مستند الإشعار نفسه حتى يكون قابلاً للتشخيص لاحقاً
    // (بدل pushSent: undefined إلى الأبد)، مع try/catch إضافي حول هذا
    // التسجيل نفسه احتياطاً (لو كان سبب الخطأ الأصلي انقطاع الاتصال
    // بـFirestore نفسه، فمحاولة الكتابة هنا ستفشل أيضاً - لا بأس).
    try {
      await notifRef.update({
        pushSent: true,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushResult: `error: ${String(e && e.message ? e.message : e)}`,
      });
    } catch (_) {}
    res.status(500).json({ error: 'internal_error', message: String(e && e.message ? e.message : e) });
  }
};
