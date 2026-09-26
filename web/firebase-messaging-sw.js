// firebase-messaging-sw.js
// -----------------------------------------------------------------------
// Service Worker مخصَّص فقط لاستقبال إشعارات Firebase Cloud Messaging على
// الويب — منفصل تماماً عن flutter_service_worker.js (الذي يولّده Flutter
// تلقائياً في كل flutter build web ولا يجوز تعديله يدوياً إطلاقاً، لأن أي
// تعديل يُفقَد عند البناء التالي).
//
// عمداً لا نُسجّل (register) هذا الملف يدوياً من كودنا وبنفس نطاق (scope)
// flutter_service_worker.js — حزمة firebase_messaging نفسها (عبر Firebase
// JS SDK) تُسجّله تلقائياً بنطاق مخصَّص منفصل تماماً
// ('/firebase-cloud-messaging-push-scope')، بالضبط لتفادي أي تعارض مع
// Service Worker الرئيسي للتطبيق. كل ما يحتاجه هذا الملف هو أن يكون موجوداً
// في جذر النطاق (وهو ما يضمنه وضعه هنا داخل web/، فتُبقيه Flutter كملف
// ثابت يُنسَخ حرفياً إلى build/web/ عند كل بناء، دون أي معالجة).
//
// القيم أدناه هي نفسها إعدادات firebase_options.dart (Web) — علنية وليست
// سرّية (نفس مبدأ google-services.json)، لا حاجة لأي تخزين خاص لها.

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyASj-jYXDSNdbIlw2eAxQ-gXnZxN_YQelY',
  appId: '1:510083510800:web:0e260e707150f4b8e69095',
  messagingSenderId: '510083510800',
  projectId: 'daftar-alhalaqah',
  authDomain: 'daftar-alhalaqah.firebaseapp.com',
  storageBucket: 'daftar-alhalaqah.firebasestorage.app',
});

const messaging = firebase.messaging();

// إشعار في الخلفية (التطبيق/الصفحة مغلقة أو التركيز على تبويب آخر) —
// نعرض إشعار نظام يدوياً هنا فقط لتحديد سلوك النقر (فتح/تركيز نافذة
// رعاية بدل الفتح الافتراضي بلا وجهة).
messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'رعاية';
  const body = (payload.notification && payload.notification.body) || '';
  self.registration.showNotification(title, {
    body,
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    dir: 'rtl',
    lang: 'ar',
    data: payload.data || {},
  });
});

// عند الضغط على الإشعار: نركّز نافذة رعاية المفتوحة أصلاً إن وُجدت،
// وإلا نفتح واحدة جديدة على المسار الرئيسي.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});
