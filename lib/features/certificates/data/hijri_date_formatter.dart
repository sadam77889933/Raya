/// تحويل ميلادي ← هجري بخوارزمية جدولية معروفة (الخوارزمية الكويتية) —
/// مستقل تماماً عن حزمة hijri الخارجية (المستخدَمة في بقية التطبيق فقط
/// لتاريخ اليوم الحالي عبر HijriCalendar.now())، لأن ميزة الشهادات تحتاج
/// أحياناً تحويل تاريخ ماضٍ (تاريخ إنشاء دُفعة قديمة عند إعادة مشاركتها)
/// لا تاريخ اليوم دائماً. دقّة تقريبية (يوم أو يومان) كافية تماماً لعرض
/// تاريخ على شهادة أو في سجل، وليست حساباً شرعياً رسمياً.
///
/// مُستخرَجة كملف مشترك (كانت خاصة بـ`CertificateBatchHistoryTile` فقط)
/// لإعادة استخدامها أيضاً في تعبئة حقل `CertificateField.date` الحقيقي
/// على الشهادة نفسها (القسم ١٣ نقطة ٧ — إضافة حقول عبر "إضافة حقل").
class ApproxHijriDate {
  final int year;
  final int month;
  final int day;
  const ApproxHijriDate(this.year, this.month, this.day);
}

ApproxHijriDate gregorianToHijri(DateTime date) {
  final jdn = _gregorianToJulianDayNumber(date.year, date.month, date.day);
  final l1 = jdn - 1948440 + 10632;
  final n = ((l1 - 1) / 10631).floor();
  final l2 = l1 - 10631 * n + 354;
  final j = (((10985 - l2) / 5316).floor()) * (((50 * l2) / 17719).floor()) +
      ((l2 / 5670).floor()) * (((43 * l2) / 15238).floor());
  final l3 = l2 -
      (((30 - j) / 15).floor()) * (((17719 * j) / 50).floor()) -
      ((j / 16).floor()) * (((15238 * j) / 43).floor()) +
      29;
  final month = ((24 * l3) / 709).floor();
  final day = l3 - ((709 * month) / 24).floor();
  final year = 30 * n + j - 30;
  return ApproxHijriDate(year, month, day);
}

int _gregorianToJulianDayNumber(int year, int month, int day) {
  final a = ((14 - month) / 12).floor();
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      ((153 * m + 2) / 5).floor() +
      365 * y +
      (y / 4).floor() -
      (y / 100).floor() +
      (y / 400).floor() -
      32045;
}

/// تسمية جاهزة للعرض المباشر: يوم/شهر/سنة + "هـ" — نفس الصيغة
/// المستخدَمة أصلاً في سجل "آخر الشهادات".
String formatHijriDateLabel(DateTime date) {
  final hijri = gregorianToHijri(date);
  return '${hijri.day}/${hijri.month}/${hijri.year}هـ';
}

/// سنة هجرية واحدة فقط (مثل "١٤٤٧هـ") لحقل "العام الدراسي" (`CertificateField.academicYear`)
/// على الشهادة — سنة واحدة لا مدى، بناءً على اختيار المشرفة الصريح.
String formatHijriYearLabel(DateTime date) {
  return '${gregorianToHijri(date).year}هـ';
}
