import 'package:equatable/equatable.dart';

/// إدخال واحد في سجلّ تعديلات/حذف أسئلة الاختبار من قِبل المشرفة.
/// يُخزَّن مضمَّناً داخل وثيقة [SummerTest] نفسها (بلا مجموعة منفصلة)
/// لأنه سجلّ صغير نادر التكرار، فلا يستحق قراءة إضافية لعرضه.
class TestAuditEntry extends Equatable {
  final String action; // 'edited' | 'deleted'
  final String questionSnapshot; // نص السؤال وقت الإجراء (للمرجعية)
  final String byUid;
  final String byName;
  final DateTime at;

  const TestAuditEntry({
    required this.action,
    required this.questionSnapshot,
    required this.byUid,
    required this.byName,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'questionSnapshot': questionSnapshot,
        'byUid': byUid,
        'byName': byName,
        'at': at.toIso8601String(),
      };

  factory TestAuditEntry.fromJson(Map<String, dynamic> json) {
    return TestAuditEntry(
      action: json['action'] as String? ?? 'edited',
      questionSnapshot: json['questionSnapshot'] as String? ?? '',
      byUid: json['byUid'] as String? ?? '',
      byName: json['byName'] as String? ?? '',
      at: DateTime.parse(json['at'] as String),
    );
  }

  @override
  List<Object?> get props => [action, questionSnapshot, byUid, byName, at];
}

/// اختبار واحد تابع لمركز صيفي — قد يوجد أكثر من اختبار لنفس (مستوى+مادة)
/// لنفس المعلمة (اختبار أول، نهائي، تعويضي...)، كل واحد وثيقة مستقلة.
class SummerTest extends Equatable {
  final String id;
  final String centerId;
  final String mosqueId;
  final String levelId;
  final String subjectId;
  final String teacherId;
  final String teacherName;
  final String title;
  final String hijriMonth;
  final String hijriYear;

  /// عدّاد مُحدَّث تراكمياً مع كل إضافة/حذف سؤال — يسمح بعرض شاشة
  /// القائمة بلا أي قراءة لمجموعة الأسئلة نفسها.
  final int questionsCount;

  final List<TestAuditEntry> auditLog;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SummerTest({
    required this.id,
    required this.centerId,
    required this.mosqueId,
    required this.levelId,
    required this.subjectId,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.hijriMonth,
    required this.hijriYear,
    this.questionsCount = 0,
    this.auditLog = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'centerId': centerId,
        'mosqueId': mosqueId,
        'levelId': levelId,
        'subjectId': subjectId,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'title': title,
        'hijriMonth': hijriMonth,
        'hijriYear': hijriYear,
        'questionsCount': questionsCount,
        'auditLog': auditLog.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SummerTest.fromJson(String id, Map<String, dynamic> json) {
    return SummerTest(
      id: id,
      centerId: json['centerId'] as String,
      mosqueId: json['mosqueId'] as String,
      levelId: json['levelId'] as String,
      subjectId: json['subjectId'] as String,
      teacherId: json['teacherId'] as String,
      teacherName: json['teacherName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      hijriMonth: json['hijriMonth'] as String? ?? '',
      hijriYear: json['hijriYear'] as String? ?? '',
      questionsCount: (json['questionsCount'] as num?)?.toInt() ?? 0,
      auditLog: (json['auditLog'] as List<dynamic>?)
              ?.map((e) => TestAuditEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(
          (json['updatedAt'] as String?) ?? (json['createdAt'] as String)),
    );
  }

  SummerTest copyWith({String? title, int? questionsCount}) {
    return SummerTest(
      id: id,
      centerId: centerId,
      mosqueId: mosqueId,
      levelId: levelId,
      subjectId: subjectId,
      teacherId: teacherId,
      teacherName: teacherName,
      title: title ?? this.title,
      hijriMonth: hijriMonth,
      hijriYear: hijriYear,
      questionsCount: questionsCount ?? this.questionsCount,
      auditLog: auditLog,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        centerId,
        mosqueId,
        levelId,
        subjectId,
        teacherId,
        teacherName,
        title,
        hijriMonth,
        hijriYear,
        questionsCount,
        auditLog,
        createdAt,
        updatedAt,
      ];
}
