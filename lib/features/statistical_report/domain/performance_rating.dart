import '../../../core/constants/quran_constants.dart';

/// منطق تحويل مؤشرات رقمية (نسب مئوية أو درجات) إلى تصنيف نصي موحّد،
/// باستخدام نفس مفردات التقييم المستخدمة أصلاً في التطبيق
/// (QuranConstants.grades: ممتاز / جيد جداً / جيد / مقبول / ضعيف) بدل
/// اختراع مصطلحات جديدة (مثل "يحتاج تحسين") غير موجودة في بقية التطبيق.
class PerformanceRating {
  PerformanceRating._();

  /// ترتيب من الأعلى للأدنى، كما في QuranConstants.grades.
  static List<String> get _grades => QuranConstants.grades;

  /// تحويل نص تقييم (كما تُدخله المعلمة) إلى درجة رقمية: ممتاز=5 ... ضعيف=1.
  /// يرجع 0 إن كان النص غير معروف/فارغ.
  static int scoreOf(String grade) {
    final i = _grades.indexOf(grade);
    return i == -1 ? 0 : (_grades.length - i);
  }

  /// تحويل متوسط رقمي (1–5) لأقرب تصنيف نصي. يرجع نصاً فارغاً إن لم تتوفر
  /// بيانات كافية (avg <= 0).
  static String gradeFromAverageScore(double avgScore) {
    if (avgScore <= 0) return '';
    final rounded = avgScore.round().clamp(1, _grades.length);
    return _grades[_grades.length - rounded];
  }

  /// تصنيف نسبة مئوية (0–100) إلى نفس مفردات التقييم الخماسية، لاستخدامها
  /// في تصنيف الحضور/السلوك ضمن "الأداء العام للحلقة" بنفس مفردات باقي
  /// التطبيق بدل مقياس منفصل.
  static String ratingFromPercent(double percent) {
    if (percent <= 0) return '';
    if (percent >= 90) return 'ممتاز';
    if (percent >= 80) return 'جيد جداً';
    if (percent >= 65) return 'جيد';
    if (percent >= 50) return 'مقبول';
    return 'ضعيف';
  }

  /// هل هذا التصنيف يُعتبر "مرتفعاً" (ممتاز/جيد جداً)؟ يُستخدم لاختيار
  /// اللون الأخضر مقابل الذهبي في رقائق الأداء العام.
  static bool isHigh(String grade) => grade == 'ممتاز' || grade == 'جيد جداً';
}
