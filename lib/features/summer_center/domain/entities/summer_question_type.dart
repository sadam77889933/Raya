/// أنواع أسئلة اختبارات المركز الصيفي.
///
/// قرار معماري متعمَّد: النوع يُخزَّن كنص حر في Firestore (وليس enum
/// Dart يُحوَّل عبر switch كما في UserRole) — إضافة نوع جديد مستقبلاً
/// (مثل "تحدّثي" أو "اشرحي") تعني فقط إضافة مفتاح جديد هنا وواجهة تحرير
/// مناسبة له، بلا أي تعديل على بنية قاعدة البيانات أو migration.
///
/// الأنواع من عائلة "المقالي" (اذكري/عرّفي/عللي وما شابه) تتشارك نفس
/// [typeData] الخاصة بـ[essay] (عدد أسطر الإجابة فقط) — تُميَّز عن بعضها
/// بمفتاح [type] مختلف فقط لغرض عرض تسمية مناسبة للمعلمة والمشرفة،
/// دون الحاجة لمحرر واجهة منفصل لكل واحدة منها.
class SummerQuestionType {
  SummerQuestionType._();

  static const String trueFalse = 'true_false';
  static const String multipleChoice = 'multiple_choice';
  static const String essay = 'essay';
  static const String fillBlank = 'fill_blank';
  static const String order = 'order';
  static const String match = 'match';
  static const String mention = 'mention'; // اذكري
  static const String define = 'define'; // عرّفي
  static const String explainWhy = 'explain_why'; // عللي

  /// كل الأنواع المتاحة حالياً، بترتيب ظهورها في شاشة اختيار النوع.
  static const List<String> all = [
    trueFalse,
    multipleChoice,
    essay,
    fillBlank,
    order,
    match,
    mention,
    define,
    explainWhy,
  ];

  /// الأنواع التي تُبنى على نفس محرر "مقالي" (نص سؤال + عدد أسطر إجابة)
  static const List<String> essayFamily = [essay, mention, define, explainWhy];

  static String label(String type) {
    switch (type) {
      case trueFalse:
        return 'صح / خطأ';
      case multipleChoice:
        return 'اختيار من متعدد';
      case essay:
        return 'مقالي';
      case fillBlank:
        return 'أكمل الفراغ';
      case order:
        return 'رتّب';
      case match:
        return 'وصّل';
      case mention:
        return 'اذكري';
      case define:
        return 'عرّفي';
      case explainWhy:
        return 'عللي';
      default:
        return type;
    }
  }
}
