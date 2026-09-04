import 'package:equatable/equatable.dart';

/// نوع مستفيدي دفعة الشهادات — طالبات أو معلمات.
///
/// المرحلة الأولى تدعم الطالبات فقط فعلياً (القالب الأساسي الوحيد مكتوب
/// بصياغة خاصة بالطالبة)، لكن القيمة موجودة من الآن حتى لا يحتاج إضافة
/// قالب معلمات لاحقاً أي تعديل على نموذج البيانات نفسه.
enum CertificateRecipientType { student, teacher }

/// دُفعة شهادات — مستند Firestore واحد **لكل عملية إنشاء**، وليس لكل
/// شهادة على حدة، لتقليل القراءات/الكتابات (نفس روح
/// firestore_reads_optimization_audit.md).
class CertificateBatch extends Equatable {
  final String id;
  final DateTime createdAt;
  final String createdByUid;
  final String createdByName;
  final String mosqueId;
  final String? mosqueNameSnapshot;
  final CertificateRecipientType recipientType;
  final String templateId;
  final List<String> recipientIds;
  final int recipientCount;
  final String? circleNameSnapshot;

  const CertificateBatch({
    required this.id,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByName,
    required this.mosqueId,
    this.mosqueNameSnapshot,
    required this.recipientType,
    required this.templateId,
    required this.recipientIds,
    required this.recipientCount,
    this.circleNameSnapshot,
  });

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        'mosqueId': mosqueId,
        if (mosqueNameSnapshot != null) 'mosqueNameSnapshot': mosqueNameSnapshot,
        'recipientType': recipientType.name,
        'templateId': templateId,
        'recipientIds': recipientIds,
        'recipientCount': recipientCount,
        if (circleNameSnapshot != null) 'circleNameSnapshot': circleNameSnapshot,
      };

  factory CertificateBatch.fromJson(String id, Map<String, dynamic> json) {
    return CertificateBatch(
      id: id,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdByUid: json['createdByUid'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
      mosqueId: json['mosqueId'] as String? ?? '',
      mosqueNameSnapshot: json['mosqueNameSnapshot'] as String?,
      recipientType: (json['recipientType'] as String?) == 'teacher'
          ? CertificateRecipientType.teacher
          : CertificateRecipientType.student,
      templateId: json['templateId'] as String? ?? '',
      recipientIds: (json['recipientIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recipientCount: json['recipientCount'] as int? ?? 0,
      circleNameSnapshot: json['circleNameSnapshot'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        createdAt,
        createdByUid,
        createdByName,
        mosqueId,
        mosqueNameSnapshot,
        recipientType,
        templateId,
        recipientIds,
        recipientCount,
        circleNameSnapshot,
      ];
}
