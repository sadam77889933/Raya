import 'package:pdf/pdf.dart';

import '../../domain/entities/certificate_batch.dart';
import '../../domain/entities/certificate_template.dart';
import '../../domain/entities/imported_certificate_template.dart';

/// قائمة مفتوحة بكل القوالب الأساسية المتاحة في التطبيق — تبدأ بعنصر
/// واحد فقط عند إطلاق المرحلة الأولى (قالب "شهادة شكر" الذي اعتمدته
/// المستخدمة). إضافة قالب أساسي جديد لاحقاً (بما فيها نسخة للمعلمات) لا
/// تحتاج أي تعديل على أي شاشة أو منطق آخر في الميزة — فقط صورة خلفية +
/// مصغّرة جديدتان + عنصر جديد هنا.
///
/// لون الحبر التقريبي المستخدَم في تصميم الشهادة نفسها (رمادي-بنّي داكن)،
/// لمطابقة النصوص المُضافة برمجياً مع النص الثابت المطبوع على الصورة.
const PdfColor _inkColor = PdfColor(0.2902, 0.2392, 0.2588); // #4A3D42

/// لون حبر النص المطبوع في تصميم "شهادة تقدير — معلمات (٢)" — ذهبي دافئ
/// (بخلاف اللون البنّي الرمادي [_inkColor] أعلاه)، عُيِّن مباشرة من عيّنة
/// بكسل داخلية غير مُبعثَرة بالتنعيم الطرفي (Anti-aliasing) على الصورة
/// الأصلية.
const PdfColor _goldInkColor = PdfColor(0.8078, 0.6235, 0.2078); // #CE9F35

/// لون حبر النص المطبوع في تصميم "شهادة القرآن الكريم — طالبات" — بنّي
/// داكن مطابق تماماً للون الإطار الزخرفي نفسه في هذا التصميم (عُيِّن من
/// عيّنة بكسل داخلية مباشرة على الصورة، لا تخميناً).
const PdfColor _darkBrownInkColor = PdfColor(0.3255, 0.1804, 0.1216); // #532E1F

/// لون حبر النص المطبوع في تصميم "شهادة تقدير — طالبات (٢)" — رمادي
/// محايد داكن (يختلف عن كل الألوان أعلاه)، عُيِّن مباشرة من عيّنة بكسل
/// داخلية غير مُبعثَرة بالتنعيم الطرفي على كلمة "بجامع" في نص الشهادة
/// الأصلية.
const PdfColor _grayInkColor = PdfColor(0.2196, 0.2196, 0.2196); // #383838

final List<CertificateTemplateDefinition> certificateTemplateRegistry = [
  CertificateTemplateDefinition(
    id: 'thanks_certificate_student',
    displayName: 'شهادة شكر — طالبات',
    backgroundImageAsset:
        'assets/images/certificate_templates/thanks_certificate_student_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/thanks_certificate_student_thumb.png',
    recipientType: CertificateRecipientType.student,
    fixedFields: const [
      // الفراغ بعد "مدرسة" — اسم الدار
      // ملاحظة مهمة: dy: 0.510 (محاولة سابقة) كانت خطأ — القياس على
      // الشهادة الفعلية أثبت أن dy: 0.458 الأصلية كانت مُحاذاة بشكل صحيح
      // فعلاً مع سطر "يسر مدرسة"، والمشكلة الوحيدة كانت صِغَر الخط لا
      // موضعه. رفع dy زاد الأمر سوءاً (تداخل مع السطر التالي)، فأُعيد
      // لقيمته الصحيحة وبقي تكبير الخط فقط.
      //
      // تحديث لاحق مع القالب الجديد (بعد توسعة المسافة بين "بجامع"
      // و"مدرسة"): dx وmaxWidthRatio أُعيد حسابهما هندسياً بدل التخمين.
      // الفراغ الفعلي المتاح لاسم المدرسة محصور بين نهاية "بجامع" (يمين)
      // ونهاية "مدرسة" (يسار) — قِيس بدقة بالبكسل على الصورة الجديدة:
      // يمتد من نسبة 0.343 إلى 0.6325 من عرض الصورة. اعتُمد صندوق بعرض
      // هذا الفراغ كاملاً (ناقص هامش أمان صغير) مع محاذاة النص إلى يمين
      // الصندوق بدل توسيطه (انظر المحرِّك): القيمة القصيرة تلتصق بكلمة
      // "مدرسة" مباشرة، والطويلة تنمو يساراً داخل كامل الفراغ الحقيقي
      // بدل الاصطدام بالتسمية من الجهتين كما كان يحدث مع التوسيط.
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.487,
        dy: 0.458,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.27,
        rightAlign: true,
      ),
      // الفراغ بعد "بجامع" — اسم المسجد (نفس سطر اسم المدرسة أعلاه)
      // نفس منهج القياس أعلاه: "بجامع" ينتهي (يسار الكلمة) عند نسبة
      // 0.28، والفراغ يمتد يساراً حتى حافة الإطار الزخرفي الآمنة قرب
      // نسبة 0.045. الصندوق بعرض هذا الفراغ كاملاً مع محاذاة يمين، بنفس
      // منطق اسم المدرسة أعلاه.
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.16,
        dy: 0.458,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.22,
        rightAlign: true,
      ),
      // السطر المنقّط بعد "هذه الشهادة لـطالبة/" — اسم الطالبة
      // كانت dy: 0.577 تتقاطع مع النقاط، ورفعها إلى 0.625 (المحاولة
      // السابقة) كان خطأً في الاتجاه — dy الأكبر يعني موضعاً أسفل الصفحة
      // لا أعلاها، فتداخل مع فقرة "على إتمامها..." تحتها. الاتجاه الصحيح
      // لرفع النص فوق النقاط هو تصغير dy لا تكبيره.
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.50,
        dy: 0.545,
        fontSize: 26,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.60,
      ),
    ],
    // تحت "مشرفة المدرسة:" مباشرة — يُقرأ من Mosque.stampBase64
    stampPosition: const CertificateStampPosition(
      dx: 0.26,
      dy: 0.855,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة تقدير" الخاص بالمعلمات — نفس منهج القياس بالبكسل
  // المعتمَد أعلاه لقالب الطالبات، مطبَّق على تصميم قالب المعلمات
  // الجديد (تخطيط مختلف قليلاً: اسم الدار واسم المسجد على سطر أعلى من
  // اسم المستفيدة، لا على نفس السطر كما في قالب الطالبات).
  CertificateTemplateDefinition(
    id: 'thanks_certificate_teacher',
    displayName: 'شهادة تقدير — معلمات',
    backgroundImageAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_thumb.png',
    recipientType: CertificateRecipientType.teacher,
    fixedFields: const [
      // اسم الدار
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.4605,
        dy: 0.362,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.28,
        rightAlign: true,
      ),
      // اسم المسجد
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.167,
        dy: 0.362,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.15,
        rightAlign: true,
      ),
      // اسم المعلمة المستفيدة
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.50,
        dy: 0.4674,
        fontSize: 24,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.50,
      ),
    ],
    stampPosition: const CertificateStampPosition(
      dx: 0.371,
      dy: 0.8465,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة تقدير" ثانٍ للطالبات — تصميم المستخدمة الخاص (اعتُمد
  // بعد معاينة صريحة: "اعتمد القالب هذا لطالبات")، يُضاف كخيار إضافي
  // بجانب "thanks_certificate_student" أعلاه، لا بديلاً عنه (بحسب
  // اختيارها الصريح لاحقاً: "يُضاف كخيار ثانٍ"). قياس كل المواضع بالبكسل
  // على الصورة الأصلية (2000×1414) بنفس المنهج المعتمَد أعلاه.
  //
  // خاصيّته المميِّزة: اسم الدار يظهر مرتين - مرة داخل الشارة/الكبسولة
  // الزخرفية تحت الشعار (حقل [CertificateField.schoolNameBadge] منفصل،
  // بنفس بيانات [CertificateField.schoolName] - انظر تعليق تعريف الـenum)
  // بلون أبيض فوق الكبسولة الخضراء الداكنة، ومرة أخرى بعد كلمة "مدرسة"
  // في نص الشهادة (تكرار مقصود بحسب اختيارها الصريح: "يعرض اسم الدار
  // أيضاً هناك").
  CertificateTemplateDefinition(
    id: 'appreciation_certificate_student',
    displayName: 'شهادة تقدير — طالبات',
    backgroundImageAsset:
        'assets/images/certificate_templates/appreciation_certificate_student_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/appreciation_certificate_student_thumb.png',
    recipientType: CertificateRecipientType.student,
    fixedFields: const [
      // اسم الدار داخل الشارة/الكبسولة تحت الشعار — كبسولة خضراء داكنة
      // مرسومة ضمن صورة الخلفية نفسها (فارغة من أي نص)، بمقاس بكسل
      // 150,400 إلى 478,458 على الصورة الأصلية. نص أبيض متوسِّط (لا محاذاة
      // يمين - الكبسولة عنصر مُتمركِز بصرياً بحد ذاته) بخط عريض لوضوحه
      // فوق الخلفية الخضراء الداكنة.
      CertificateFieldPosition(
        field: CertificateField.schoolNameBadge,
        dx: 0.157,
        dy: 0.303,
        fontSize: 15,
        color: PdfColors.white,
        bold: true,
        maxWidthRatio: 0.15,
      ),
      // اسم الدار بعد كلمة "مدرسة" في نص الشهادة - الفراغ الفعلي ممتد من
      // نهاية "مدرسة" (يمين، نسبة ≈0.625) حتى بداية "بجامع" (يسار، نسبة
      // ≈0.38)، فاعُتمد صندوق بعرض جزء آمن من هذا الفراغ مع محاذاة يمين
      // (يلتصق بكلمة "مدرسة" مباشرة كما في القالب الأول).
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.515,
        dy: 0.361,
        fontSize: 20,
        bold: true,
        maxWidthRatio: 0.22,
        rightAlign: true,
      ),
      // اسم المسجد بعد كلمة "بجامع" (نفس سطر اسم الدار أعلاه) - الفراغ
      // الفعلي ممتد من نهاية "بجامع" (يمين، نسبة ≈0.325) حتى حافة الإطار
      // الزخرفي الآمنة (يسار، نسبة ≈0.08).
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.21,
        dy: 0.361,
        fontSize: 20,
        bold: true,
        maxWidthRatio: 0.23,
        rightAlign: true,
      ),
      // اسم الطالبة مباشرة بعد حرف "/" في سطر "بخالص الشكر والتقدير
      // للطالبة/" (بلا سطر منقّط أو فراغ ظاهر في الصورة الأصلية - محاذاة
      // يمين تُلصِق الاسم بالحرف "/" مباشرة بحسب اختيار المستخدمة الصريح:
      // "مباشرة بعد '/' بنفس السطر").
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.2375,
        dy: 0.406,
        fontSize: 24,
        bold: true,
        maxWidthRatio: 0.55,
        rightAlign: true,
      ),
    ],
    // لا يوجد أي دليل مطبوع (دائرة منقّطة أو غيرها) لموضع الختم في تصميم
    // المستخدمة الأصلي قرب تسميات التوقيع الثلاث ("المشرفة"/"المعلمة"/
    // "المديرة") - اعتُمد الفراغ الأبيض الطبيعي أعلى تسمية "المشرفة"
    // تحديداً (بنفس منطق القالبين أعلاه: الختم فوق توقيع المشرفة)، قابل
    // للتعديل الكامل لاحقاً عبر محرر مواضع الحقول كأي قالب آخر.
    stampPosition: const CertificateStampPosition(
      dx: 0.741,
      dy: 0.69,
      widthRatio: 0.09,
    ),
  ),
  // قالب شهادة شكر وعرفان ثانٍ للمعلمات — تصميم المستخدمة الخاص (طلبت إضافته صراحةً: "ساعطيك قالب شهاده للمعلمة . قم باضافتها في قالب المعلمات")، يُضاف كخيار إضافي بجانب "thanks_certificate_teacher" أعلاه، لا بديلاً عنه (بنفس نمط "appreciation_certificate_student" مع "thanks_certificate_student"). قياس كل المواضع بالبكسل على الصورة الأصلية (2000×1414) بنفس المنهج المعتمد أعلاه — تحليل عمودي/أفقي دقيق لكثافة البكسلات الداكنة (لا تخمين بصري) لتحديد حدود كل عنصر ثابت مطبوع، مع احترازات ضد تلوث القياس بعناصر زخرفية مجاورة (الرسم الزخرفي الملوّن أعلى يسار السطر الأول، وأيقونة المصحف الزخرفية أعلى يمين السطر الأخير — كلاهما لا علاقة له بأي حقل ديناميكي).
  //
  // لا يوجد حقل لاسم المسجد في هذا التصميم إطلاقاً (بخلاف كل القوالب السابقة) - سطر "مقدمة من:" الوحيد يعرض اسم الدار فقط بحسب اختيار المستخدمة الصريح: "اسم الدار فقط". كذلك سطر توقيع "مديرة المدرسة" (يمين الشهادة) يبقى فراغاً للتوقيع اليدوي الفعلي بلا أي حقل نصي، تماماً كحقول التوقيع غير المُفعّلة في القالب الثاني للطالبات أعلاه — لم تطلب المستخدمة أي حقل له.
  CertificateTemplateDefinition(
    id: 'appreciation_certificate_teacher',
    displayName: 'شهادة شكر وعرفان — معلمات',
    backgroundImageAsset:
        'assets/images/certificate_templates/appreciation_certificate_teacher_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/appreciation_certificate_teacher_thumb.png',
    recipientType: CertificateRecipientType.teacher,
    fixedFields: const [
      // اسم المعلمة المستفيدة مباشرة بعد حرف "/" في سطر "الأستاذة/" (سطر منقّط ممتد من نهاية "/" يميناً حتى الحافة الزخرفية يساراً) - محاذاة يمين تلصق الاسم بالحرف "/" مباشرة بحسب اختيار المستخدمة الصريح: "ملتصق مباشرة بعد '/' (يمين)". الفراغ الفعلي الممتد على السطر المنقّط قيس بدقة: من نهاية "/" (يمين، نسبة ≈ 0.666) حتى بداية السطر المنقّط (يسار، نسبة ≈ 0.2985)، فاعُمد عرض صندوق يطابق تقريباً هذا الفراغ (0.37) بدل التمدد بالتساوي في الاتجاهين والاصطدام بكلمة "الأستاذة".
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.481,
        dy: 0.363,
        fontSize: 26,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.37,
        rightAlign: true,
      ),
      // اسم الدار تحت "مقدمة من:" (سطر مستقل أسفلها، لا بجانبها) بحسب
      // تعديل المستخدمة الصريح لاحقاً: "اجعل اسم الدار تحت 'مقدمة من:'
      // وليس بجانبها". الموضع الأفقي (توسيط، لا يمين) يطابق مركز عبارة
      // "مقدمة من:" نفسها (نسبة ≈ 0.50)، وهو نفس المركز الأفقي للفراغ
      // الأبيض المحصور فعلياً بين الزخرفتين المزهَّرتين أسفل يمين ويسار
      // الشهادة (من نهاية الزخرفة اليسرى عند نسبة ≈ 0.377 حتى بداية
      // الزخرفة اليمنى عند نسبة ≈ 0.626) - تصميم مقصود يضع اسم الدار
      // بينهما تحديداً. الموضع الرأسي يطابق المركز الرأسي لهاتين
      // الزخرفتين (نسبة ≈ 0.89)، أسفل نص "مقدمة من:" (ينتهي عند نسبة
      // ≈ 0.83) بفراغ واضح بينهما.
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.50,
        dy: 0.89,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.28,
      ),
    ],
    // موضع الختم تحت تسمية "مشرفة الجامع" تحديداً (وليس أيقونة المصحف الزخرفية المجاورة، ولا تسمية "مديرة المدرسة" على الطرف الآخر) بحسب اختيار المستخدمة الصريح: "تحت 'مشرفة الجامع'" - في الفراغ الأبيض الفعلي بين نهاية التسمية (أسفل، نسبة ≈ 0.729) وبداية سطرها المنقّط (أعلى، نسبة ≈ 0.777)، بنفس منطق كل القوالب أعلاه (الختم فوق سطر التوقيع مباشرة لا فوقه).
    stampPosition: const CertificateStampPosition(
      dx: 0.326,
      dy: 0.753,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة تقدير" ثالث للمعلمات — تصميم المستخدمة الخاص (طلبت إضافته صراحةً: "اريد اضافة قالب ايضا للمعلمات")، يُضاف كخيار ثالث بجانب "thanks_certificate_teacher" و"appreciation_certificate_teacher" أعلاه، لا بديلاً عن أيّ منهما. عنوانه المطبوع "شهادة تقدير" مطابق حرفياً لعنوان "thanks_certificate_teacher" رغم اختلاف التصميم والنص كلياً - لذا اعتُمد `displayName` مميَّز صراحةً بطلب المستخدمة: "شهادة تقدير — معلمات (٢)"، حتى لا يلتبس بالقالب الآخر في قائمة الاختيار. قياس كل المواضع بالبكسل على الصورة الأصلية (2000×1414) بتحليل عمودي/أفقي دقيق لكثافة البكسلات (لا تخمين بصري) - بما في ذلك تفكيك السطرين الرئيسيين إلى تجمّعات كلمات لتحديد الفراغات الثلاثة بدقة (تبيَّن أن الجملة الواحدة "بكل فخر واعتزاز، تمنح مدرسة (اسم الدار) بجامع (اسم المسجد) هذه الشهادة للمعلمة/ (اسم المعلمة)" موزَّعة فعلياً على سطرين: السطر الأول ينتهي بفراغ اسم الدار حتى الحافة اليسرى، والسطر الثاني يبدأ من اليمين بكلمة "بجامع" ثم فراغ اسم المسجد، ثم عبارة "هذه الشهادة للمعلمة/" ثم فراغ اسم المعلمة حتى الحافة اليسرى).
  //
  // اسم الدار واسم المسجد بلا أي دليل مطبوع (فراغان أبيضان تماماً)، أما
  // اسم المعلمة فله خط أفقي رفيع فعلي أسفل عبارة "هذه الشهادة للمعلمة/"
  // (اكتُشِف بعد ملاحظة صريحة من المستخدمة - انظر تعليق حقل recipientName
  // أدناه). لا يوجد أي دليل مطبوع لموضع الختم في هذا التصميم - اعتُمد
  // (بعد تصحيح لاحق أيضاً) الفراغ الأبيض الفعلي أسفل تسمية "المشرفة"
  // تحديداً، قابل للتعديل الكامل لاحقاً عبر محرر مواضع الحقول كأي قالب
  // آخر. تسمية "المديرة" تبقى بلا أي حقل نصي مرتبط - فراغ توقيع يدوي
  // فعلي فقط، لم تطلب المستخدمة حقلاً له.
  //
  // لون النص الديناميكي هنا ذهبي ([_goldInkColor]) لا بنّي رمادي ([_inkColor]) - مطابقةً للون حبر النص المطبوع الفعلي في هذا التصميم تحديداً (عُيِّن من عيّنة بكسل داخلية مباشرة، لا تخميناً).
  CertificateTemplateDefinition(
    id: 'thanks_certificate_teacher_v2',
    displayName: 'شهادة تقدير — معلمات (٢)',
    backgroundImageAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_v2_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_v2_thumb.png',
    recipientType: CertificateRecipientType.teacher,
    fixedFields: const [
      // اسم الدار مباشرة بعد كلمة "مدرسة" في السطر الأول ("بكل فخر واعتزاز، تمنح مدرسة/") - الفراغ الفعلي يمتد من نهاية "مدرسة" (يمين، نسبة ≈ 0.384) حتى الحافة الزخرفية الآمنة يساراً، فاعُتمد عرض صندوق آمن (0.32) ضمن هذا الفراغ.
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.224,
        dy: 0.340,
        fontSize: 20,
        color: _goldInkColor,
        bold: true,
        maxWidthRatio: 0.32,
        rightAlign: true,
      ),
      // اسم المسجد مباشرة بعد كلمة "بجامع" في بداية السطر الثاني (يمين السطر) - فراغ ضيّق نسبياً بين نهاية "بجامع" (نسبة ≈ 0.647) وبداية عبارة "هذه الشهادة للمعلمة/" (نسبة ≈ 0.508)، فاعُتمد عرض صندوق يطابق هذا الفراغ الضيّق تحديداً (0.14) بدل التمدد والاصطدام بالعبارة التالية.
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.577,
        dy: 0.390,
        fontSize: 20,
        color: _goldInkColor,
        bold: true,
        maxWidthRatio: 0.14,
        rightAlign: true,
      ),
      // اسم المعلمة المستفيدة على الخط الأفقي الرفيع الواقع أسفل عبارة
      // "هذه الشهادة للمعلمة/" مباشرة (لا مُلصَقاً بحرف "/" على نفس السطر
      // كما اعتُمد مبدئياً) - بحسب ملاحظة المستخدمة الصريحة لاحقاً: "المفروض
      // اسم المعلمه يكون تحت على الخط". هذا الخط مقاس بدقة (من نسبة ≈ 0.685
      // يميناً حتى ≈ 0.3145 يساراً، عرضه ≈ 0.37 من عرض الصورة)، فتوسَّط
      // الاسم عليه أفقياً (لا محاذاة يمين بعد الآن) برأسي في الفراغ الفعلي
      // بين نهاية عبارة "هذه الشهادة للمعلمة/" (نسبة ≈ 0.420) وبداية الخط
      // نفسه (نسبة ≈ 0.490).
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.50,
        dy: 0.455,
        fontSize: 24,
        color: _goldInkColor,
        bold: true,
        maxWidthRatio: 0.37,
      ),
    ],
    // موضع الختم أسفل تسمية "المشرفة" مباشرة (لا أعلاها) بحسب ملاحظة
    // المستخدمة الصريحة لاحقاً: "الختم فوق اسم المشرفة المفروض يكون تحت
    // اسم المشرفة" - في الفراغ الأبيض الفعلي الواقع بين نهاية التسمية
    // (أسفل، نسبة ≈ 0.782) وبداية الإطار الزخرفي السفلي (أعلى، نسبة
    // ≈ 0.959)، بعيداً عن الزخرفة الزهرية في الزاوية السفلية اليسرى (لا
    // يوجد أي دليل مطبوع آخر لموضع الختم في هذا التصميم إطلاقاً). المحاذاة
    // الأفقية (نسبة ≈ 0.24) أُزيحت يميناً قليلاً عن مركز التسمية نفسها
    // (نسبة ≈ 0.193) تحديداً لتفادي تداخل الختم مع تلك الزخرفة الزهرية،
    // التي تمتد حتى نسبة ≈ 0.173 كحد أقصى في هذا النطاق الرأسي.
    stampPosition: const CertificateStampPosition(
      dx: 0.24,
      dy: 0.870,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة القرآن الكريم" جديد للطالبات - تصميم المستخدمة الخاص
  // (طلبت إضافته صراحةً: "اريد اضافة قالب للطالبات")، يُضاف كخيار ثالث
  // بجانب "thanks_certificate_student" و"appreciation_certificate_student"
  // القائمين أعلاه، لا بديلاً عن أيّ منهما. عنوانه المطبوع "القرآن الكريم"
  // (لا "شهادة شكر" ولا "شهادة تقدير" كالقالبين الآخرين)، فاعتُمد
  // `displayName` مطابق له مباشرة: "شهادة القرآن الكريم — طالبات"، بلا
  // أي تصادم مع القوالب القائمة.
  //
  // قياس كل المواضع بالبكسل على الصورة الأصلية (2000×1414) بتحليل
  // عمودي/أفقي دقيق لكثافة البكسلات (لا تخمين بصري)، بما في ذلك تفكيك كل
  // سطر إلى تجمّعات كلمات لتحديد حدود كل فراغ بدقة، والتمييز بين نص
  // التسمية وسطرها المنقّط عبر عزل النطاق الرأسي الدقيق لكلٍّ منهما (نفس
  // منهجية القوالب السابقة).
  //
  // لا يوجد أي دليل مطبوع لموضع الختم في هذا التصميم - اعتُمد (بنفس
  // الدرس المستفاد من ملاحظة المستخدمة على القالب السابق: الختم يوضَع
  // أسفل تسمية المشرفة لا أعلاها) الفراغ الأبيض الفعلي بين نهاية تسمية
  // "المشرفة" وبداية الإطار الزخرفي السفلي، بمحاذاة أفقية على مركز
  // التسمية نفسها. تسمية "المديرة" تبقى بلا أي حقل نصي مرتبط - فراغ
  // توقيع يدوي فعلي فقط، لم تطلب المستخدمة حقلاً له.
  //
  // لون النص الديناميكي هنا بنّي داكن ([_darkBrownInkColor]) مطابق للون
  // الإطار الزخرفي نفسه في هذا التصميم تحديداً (عُيِّن من عيّنة بكسل
  // داخلية مباشرة، لا تخميناً) - مختلف عن `_inkColor` و`_goldInkColor`
  // المستخدَمين في القوالب الأخرى.
  CertificateTemplateDefinition(
    id: 'quran_certificate_student',
    displayName: 'شهادة القرآن الكريم — طالبات',
    backgroundImageAsset:
        'assets/images/certificate_templates/quran_certificate_student_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/quran_certificate_student_thumb.png',
    recipientType: CertificateRecipientType.student,
    fixedFields: const [
      // اسم الطالبة مباشرة بعد حرف "/" في "شكر وتقدير الى/" - على السطر
      // المنقّط الفعلي الممتد من نهاية "/" (يمين، نسبة ≈ 0.543) حتى بداية
      // الخط المنقّط (يسار، نسبة ≈ 0.251)، فاعُتمد عرض صندوق يطابق هذا
      // الفراغ (0.28).
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.403,
        dy: 0.250,
        fontSize: 26,
        color: _darkBrownInkColor,
        bold: true,
        maxWidthRatio: 0.28,
        rightAlign: true,
      ),
      // اسم الدار مباشرة بعد كلمة "مدرسة" - أُعيد قياسه بعد أن أرسلت
      // المستخدمة نسخة مُعدَّلة من التصميم (فقرة الشكر أُعيد التفافها على
      // نفس عدد الأسطر لكن بنقاط فصل مختلفة، ما حرَّك هذا السطر تحديداً
      // عن موضعه في النسخة الأولى). الفراغ الفعلي بين نهاية "مدرسة" (نسبة
      // ≈ 0.6085) وبداية "بجامع" على نفس السطر (نسبة ≈ 0.362) أوسع من
      // النسخة الأولى، فاعُتمد عرض صندوق أكبر يطابقه (0.24).
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.489,
        dy: 0.320,
        fontSize: 20,
        color: _darkBrownInkColor,
        bold: true,
        maxWidthRatio: 0.24,
        rightAlign: true,
      ),
      // اسم المسجد مباشرة بعد كلمة "بجامع" - أُعيد قياسه لنفس السبب أعلاه؛
      // الفراغ الفعلي يمتد من نهاية "بجامع" (يمين، نسبة ≈ 0.3115) حتى
      // الحافة الزخرفية الآمنة يساراً.
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.182,
        dy: 0.320,
        fontSize: 20,
        color: _darkBrownInkColor,
        bold: true,
        maxWidthRatio: 0.26,
        rightAlign: true,
      ),
    ],
    // لا يوجد أي دليل مطبوع لموضع الختم في هذا التصميم - أُعيد قياسه أيضاً
    // على النسخة المُعدَّلة (تسمية "المشرفة" انزاحت هي الأخرى قليلاً عن
    // موضعها في النسخة الأولى). اعتُمد الفراغ الأبيض الفعلي بين نهاية
    // التسمية (نسبة ≈ 0.741) وبداية الإطار الزخرفي السفلي (نسبة ≈ 0.819)،
    // بمحاذاة أفقية على مركز التسمية نفسها (نسبة ≈ 0.352) - أسفل التسمية
    // مباشرة لا أعلاها، بناءً على ملاحظة المستخدمة على القالب السابق.
    stampPosition: const CertificateStampPosition(
      dx: 0.352,
      dy: 0.780,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة تقدير" ثانٍ للطالبات — تصميم مختلف تماماً عن
  // "appreciation_certificate_student" أعلاه رغم تطابق العنوان المطبوع
  // "شهادة تقدير" بين الاثنين؛ لتفادي الالتباس بينهما في قائمة القوالب
  // اختارت المستخدمة صراحةً تسمية العرض "شهادة تقدير — طالبات (٢)" (بنفس
  // نمط التمييز المعتمد سابقاً لقالب "thanks_certificate_teacher_v2").
  // قياس كل المواضع بالبكسل على الصورة الأصلية (2000×1414) بنفس المنهج
  // المعتمد أعلاه — تحليل عمودي/أفقي دقيق لكثافة البكسلات الداكنة (لا
  // تخمين بصري) لتحديد حدود كل عنصر ثابت مطبوع، مع احترازات ضد تلوث
  // القياس بالإطار الزخرفي المحيط وزخارف الزوايا.
  //
  // يضم أسفل هذا التصميم ثلاث تسميات: "المشرفة" (يسار، مع خط توقيع
  // تحتها)، "التاريخ" (وسط، نص ثابت بلا أي خط توقيع تحته إطلاقاً)،
  // و"المديرة" (يمين، مع خط توقيع تحتها أيضاً) - كلاهما (التاريخ
  // والمديرة) يُترك فراغاً للتعبئة/التوقيع اليدوي بلا أي حقل نصي مرتبط،
  // تماماً كحقول التوقيع غير المُفعّلة في قوالب أخرى سابقة، إذ لم تطلب
  // المستخدمة أي حقل لهما.
  CertificateTemplateDefinition(
    id: 'appreciation_certificate_student_v2',
    displayName: 'شهادة تقدير — طالبات (٢)',
    backgroundImageAsset:
        'assets/images/certificate_templates/appreciation_certificate_student_v2_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/appreciation_certificate_student_v2_thumb.png',
    recipientType: CertificateRecipientType.student,
    fixedFields: const [
      // اسم الدار بعد كلمة "مدرسة" في سطر "تمنح مدرسة ___ بجامع ___" -
      // الفراغ الفعلي ممتد من نهاية "مدرسة" (يمين، نسبة ≈0.6215) حتى
      // بداية "بجامع" على نفس السطر (يسار، نسبة ≈0.332)، فاعُتمد عرض
      // صندوق آمن (0.26) بمحاذاة يمين تلتصق بكلمة "مدرسة" مباشرة.
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.4915,
        dy: 0.333,
        fontSize: 20,
        color: _grayInkColor,
        bold: true,
        maxWidthRatio: 0.26,
        rightAlign: true,
      ),
      // اسم المسجد بعد كلمة "بجامع" (نفس السطر أعلاه) - الفراغ الفعلي
      // ممتد من نهاية "بجامع" (يمين، نسبة ≈0.2795) حتى الحافة الزخرفية
      // الآمنة يساراً.
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.1745,
        dy: 0.333,
        fontSize: 20,
        color: _grayInkColor,
        bold: true,
        maxWidthRatio: 0.21,
        rightAlign: true,
      ),
      // اسم الطالبة على الخط الأفقي الفعلي أسفل سطر "هذه الشهادة إلى
      // الطالبة:" (لا التصاقاً بنهاية السطر نفسه) - الخط ممتد أفقياً من
      // نسبة ≈0.3105 إلى ≈0.718، فاعُتمد حقل متمركز (بلا rightAlign) بعرض
      // صندوق يطابق عرض الخط تقريباً، وارتفاع يتوسط الفراغ الرأسي بين
      // نهاية نص التسمية أعلاه وبداية الخط نفسه.
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.5143,
        dy: 0.444,
        fontSize: 24,
        color: _grayInkColor,
        bold: true,
        maxWidthRatio: 0.40,
      ),
    ],
    // لا يوجد أي دليل مطبوع لموضع الختم في هذا التصميم. اعتُمد الفراغ
    // الأبيض الطبيعي أسفل خط توقيع "المشرفة" مباشرة (لا أعلاه)، بناءً على
    // ملاحظة المستخدمة الصريحة على قالب سابق: "الختم فوق اسم المشرفه
    // المفروض يكون تحت اسم المشرفة" - بمحاذاة أفقية على مركز الخط نفسه
    // (نسبة ≈0.239)، وبعرض (0.09) متسق مع بقية القوالب.
    stampPosition: const CertificateStampPosition(
      dx: 0.239,
      dy: 0.904,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة تقدير" رابع للمعلمات — تصميم مختلف تماماً عن
  // "thanks_certificate_teacher" و"thanks_certificate_teacher_v2" أعلاه رغم
  // تطابق العنوان المطبوع "شهادة تقدير" بين الثلاثة؛ لتفادي الالتباس بينها
  // في قائمة القوالب اختارت المستخدمة صراحةً تسمية العرض "شهادة تقدير —
  // معلمات (٣)" (بنفس نمط التمييز المعتمد سابقاً). قياس كل المواضع بالبكسل
  // على الصورة الأصلية (2000×1414) بنفس المنهج المعتمد أعلاه — تحليل
  // عمودي/أفقي دقيق لكثافة البكسلات الداكنة (لا تخمين بصري)، مع احترازات
  // ضد تلوث القياس بالإطار الزخرفي المحيط وزخارف الزوايا وخلفية الشيفرون
  // الزخرفية الفاتحة في هذا التصميم تحديداً.
  //
  // اسم الدار واسم المسجد هنا يقعان على سطرين متتاليين من نفس الجملة
  // المُلتفة (لا على سطر واحد كبقية القوالب): "... من مدرسة [الدار]"
  // ينتهي بها السطر الأول، ثم يبدأ السطر الثاني بـ"بجامع [المسجد] ،
  // لما ..." - بنفس نمط الالتفاف على سطرين المكتشَف سابقاً في
  // "thanks_certificate_teacher_v2" (القسم ١٦). لون حبر النص الديناميكي في
  // هذا التصميم أسود خالص فعلياً (عُيِّن من عيّنة بكسل داخلية مباشرة على
  // كلمة "مدرسة")، فلا حاجة لأي ثابت لون جديد - القيمة الافتراضية
  // [PdfColors.black] تُستخدَم كما هي.
  CertificateTemplateDefinition(
    id: 'thanks_certificate_teacher_v3',
    displayName: 'شهادة تقدير — معلمات (٣)',
    backgroundImageAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_v3_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_v3_thumb.png',
    recipientType: CertificateRecipientType.teacher,
    fixedFields: const [
      // اسم المعلمة على الخط الأفقي الفعلي أسفل سطر "يسرنا منح هذه
      // الشهادة إلى:" (لا التصاقاً بالسطر نفسه) - الخط ممتد أفقياً من
      // نسبة ≈0.2975 إلى ≈0.6985، فاعُتمد حقل متمركز (بلا rightAlign) بعرض
      // صندوق يطابق عرض الخط تقريباً، بارتفاع يتوسط الفراغ الرأسي بين
      // نهاية نص التسمية أعلاه وبداية الخط نفسه.
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.498,
        dy: 0.4587,
        fontSize: 24,
        bold: true,
        maxWidthRatio: 0.38,
      ),
      // اسم الدار مباشرة بعد كلمة "مدرسة" في نهاية السطر الأول من الجملة
      // - الفراغ الفعلي ممتد من نهاية "مدرسة" (يمين، نسبة ≈0.4230) حتى
      // الحافة اليسرى للسطر (لا كلمة أخرى تحدّه من اليسار في هذا السطر).
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.248,
        dy: 0.561,
        fontSize: 20,
        bold: true,
        maxWidthRatio: 0.35,
        rightAlign: true,
      ),
      // اسم المسجد مباشرة بعد كلمة "بجامع" في بداية السطر الثاني (يمين) -
      // الفراغ الفعلي ضيّق نسبياً، ممتد من نهاية "بجامع" (نسبة ≈0.8490)
      // حتى قبل الفاصلة "،" وبداية "لما..." (نسبة ≈0.7405)، فاعُتمد عرض
      // صندوق آمن (0.10) يتجنّب الفاصلة.
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.799,
        dy: 0.633,
        fontSize: 20,
        bold: true,
        maxWidthRatio: 0.10,
        rightAlign: true,
      ),
    ],
    // لا يوجد أي دليل مطبوع لموضع الختم في هذا التصميم (لا "التاريخ" في
    // هذا القالب أصلاً، بخلاف "appreciation_certificate_student_v2"
    // السابق). اعتُمد الفراغ الأبيض الفعلي أسفل الخط المنقّط تحت تسمية
    // "المشرفة" مباشرة (لا أعلاه)، بنفس القاعدة المعتمدة منذ ملاحظة
    // المستخدمة على قالب سابق (القسم ١٦: "الختم فوق اسم المشرفه المفروض
    // يكون تحت اسم المشرفة") - بمحاذاة أفقية على مركز الخط نفسه (نسبة
    // ≈0.282)، في الفراغ الضيّق بين الخط ونهاية الإطار الزخرفي السفلي.
    stampPosition: const CertificateStampPosition(
      dx: 0.282,
      dy: 0.906,
      widthRatio: 0.09,
    ),
  ),
];

/// القوالب المتاحة لنوع مستفيد معيّن فقط — تُستخدم في خطوة اختيار القالب
/// بالمعالج، حتى لا يظهر قالب مكتوب بصياغة غير مناسبة لنوع المستفيد
/// المختار.
List<CertificateTemplateDefinition> certificateTemplatesFor(
    CertificateRecipientType recipientType) {
  return certificateTemplateRegistry
      .where((t) => t.recipientType == recipientType)
      .toList();
}

CertificateTemplateDefinition? certificateTemplateById(String id) {
  for (final t in certificateTemplateRegistry) {
    if (t.id == id) return t;
  }
  return null;
}

/// تحلّ معرِّف قالب مخزَّن (كمعرِّف القالب المختار في معالج إنشاء شهادة)
/// إلى تعريفه الفعلي — تبحث أولاً بين القوالب الأساسية المُجمَّعة
/// ([certificateTemplateById])، ثم بين القوالب **المستورَدة** لنفس المسجد
/// (إن مُرِّرت — القسم ٦ من تصميم الميزة)، بلا حاجة لمعرفة مسبقة من
/// المستدعي إن كان هذا المعرِّف لقالب أساسي أم مستورَد.
CertificateTemplateDefinition? resolveTemplateById(
  String id,
  List<ImportedCertificateTemplate> importedTemplates,
) {
  final builtIn = certificateTemplateById(id);
  if (builtIn != null) return builtIn;
  for (final t in importedTemplates) {
    if (t.id == id) return t.toDefinition();
  }
  return null;
}
