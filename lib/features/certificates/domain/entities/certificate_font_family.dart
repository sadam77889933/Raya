/// قائمة الخطوط العربية المُجمَّعة داخل التطبيق فقط — وليست خط نظام
/// حرّاً — لكل حقل نصي في قالب شهادة (القسم ١٣ من تصميم الميزة).
///
/// حصر الاختيار بقائمة مُجمَّعة (ملفات `.ttf` مرفقة فعلياً في
/// `assets/fonts/`) يضمن تطابقاً تاماً بين ما تراه المشرفة في المحرر
/// وما يظهر في ملف PDF النهائي، ويعمل بلا إنترنت دائماً — بنفس فلسفة
/// القوالب الأساسية.
enum CertificateFontFamily {
  amiri,
  tajawal,
  mirza,
  katibeh,
  lalezar,
}

extension CertificateFontFamilyX on CertificateFontFamily {
  /// اسم معروض للمشرفة عند اختيار الخط من القائمة المنسدلة.
  String get displayName {
    switch (this) {
      case CertificateFontFamily.amiri:
        return 'أميري (تقليدي)';
      case CertificateFontFamily.tajawal:
        return 'تجوّل (عصري)';
      case CertificateFontFamily.mirza:
        return 'ميرزا (خط يدوي)';
      case CertificateFontFamily.katibeh:
        return 'كاتبة (هندسي)';
      case CertificateFontFamily.lalezar:
        return 'لالزار (عريض)';
    }
  }

  /// اسم عائلة الخط كما هو مُسجَّل في `pubspec.yaml` — يُستخدَم فقط
  /// لمعاينة اسم الخط بشكله الفعلي داخل القائمة المنسدلة في المحرر
  /// (بلا أي علاقة بتحميل الخط داخل ملف PDF، الذي يعتمد مساراً مباشراً
  /// عبر [CertificateFontFamilyX.ttfAssetPath] في طبقة البيانات).
  String get flutterFamilyName {
    switch (this) {
      case CertificateFontFamily.amiri:
        return 'Amiri';
      case CertificateFontFamily.tajawal:
        return 'Tajawal';
      case CertificateFontFamily.mirza:
        return 'Mirza';
      case CertificateFontFamily.katibeh:
        return 'Katibeh';
      case CertificateFontFamily.lalezar:
        return 'Lalezar';
    }
  }
}
