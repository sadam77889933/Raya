import 'package:equatable/equatable.dart';

/// سؤال واحد تابع لاختبار واحد ([testId]) — مجموعة مسطّحة منفصلة
/// (وليست subcollection)، بنفس أسلوب باقي مجموعات المشروع.
///
/// [order] رقم فرز فقط (يُخزَّن بفواصل كبيرة، مثلاً 1000 و2000 و3000،
/// ليسمح بإدراج سؤال بين اثنين لاحقاً بقيمة وسيطة دون إعادة كتابة كل
/// الأسئلة). رقم السؤال المعروض للمستخدمة (1، 2، 3...) هو ببساطة موضعه
/// بعد الفرز بـ[order] — وليس حقلاً مخزَّناً — فحذف سؤال يُعيد ترقيم
/// البقية تلقائياً بلا أي كتابة إضافية على الأسئلة الأخرى.
///
/// [typeData] خريطة مرنة حسب [type] (راجع [SummerQuestionType]):
/// - multiple_choice: {'options': List<String>, 'correctIndex': int?}
/// - true_false: {'correctAnswer': bool?}
/// - essay/mention/define/explain_why: {'answerLines': int}
/// - fill_blank: {'answers': List<String>?} — عدد الفراغات = عدد عناصر
///   القائمة، وموضعها داخل [questionText] بعلامة `___` نصية.
/// - order: {'items': List<String>} — بالترتيب الصحيح (تُطبَع مخلوطة).
/// - match: {'pairs': [{'left': String, 'right': String}, ...]}
class SummerTestQuestion extends Equatable {
  final String id;
  final String testId;
  final String type;
  final double order;
  final String questionText;
  final Map<String, dynamic> typeData;
  final DateTime createdAt;

  const SummerTestQuestion({
    required this.id,
    required this.testId,
    required this.type,
    required this.order,
    required this.questionText,
    this.typeData = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'testId': testId,
        'type': type,
        'order': order,
        'questionText': questionText,
        'typeData': typeData,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SummerTestQuestion.fromJson(String id, Map<String, dynamic> json) {
    return SummerTestQuestion(
      id: id,
      testId: json['testId'] as String,
      type: json['type'] as String? ?? 'essay',
      order: (json['order'] as num?)?.toDouble() ?? 0,
      questionText: json['questionText'] as String? ?? '',
      typeData: (json['typeData'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  SummerTestQuestion copyWith({
    String? type,
    double? order,
    String? questionText,
    Map<String, dynamic>? typeData,
  }) {
    return SummerTestQuestion(
      id: id,
      testId: testId,
      type: type ?? this.type,
      order: order ?? this.order,
      questionText: questionText ?? this.questionText,
      typeData: typeData ?? this.typeData,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, testId, type, order, questionText, typeData, createdAt];
}
