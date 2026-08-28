/// إشعار داخل التطبيق — ثلاثة أنواع:
/// 1. تلقائي: معلمة رفعت تقريراً (تراه المشرفات)
/// 2. رسالة يدوية: مشرفة تُرسل تذكيراً للمعلمات
/// 3. نقل طالبة: يصل حصراً لمعلمة الحلقة السابقة، ومعلمة الحلقة الجديدة
///    (عبر [recipientUid])، وللمشرف العام (عبر audienceRole+targetMosqueId
///    فقط بلا recipientUid، لأن المشرف العام ليس "مستخدماً واحداً" بمعنى
///    مطالبة كل مشرف عام مستقبلي برؤية نفس الإشعار).
class AppNotification {
  final String id;
  final String type; // 'report_created' | 'custom_message' | 'student_transfer'
  final String audienceRole; // 'supervisor' | 'teacher'
  final String? targetMosqueId; // null = يشمل كل المساجد
  final String? recipientUid; // null = موجَّه بحسب audienceRole+targetMosqueId فقط، وليس لمستخدم واحد بعينه
  final String title;
  final String body;
  final String senderName;
  final DateTime createdAt;
  final List<String> readBy;

  const AppNotification({
    required this.id,
    required this.type,
    required this.audienceRole,
    this.targetMosqueId,
    this.recipientUid,
    required this.title,
    required this.body,
    required this.senderName,
    required this.createdAt,
    this.readBy = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'audienceRole': audienceRole,
        'targetMosqueId': targetMosqueId,
        'recipientUid': recipientUid,
        'title': title,
        'body': body,
        'senderName': senderName,
        'createdAt': createdAt.toIso8601String(),
        'readBy': readBy,
      };

  factory AppNotification.fromJson(String id, Map<String, dynamic> json) {
    return AppNotification(
      id: id,
      type: json['type'] as String? ?? 'custom_message',
      audienceRole: json['audienceRole'] as String? ?? 'teacher',
      targetMosqueId: json['targetMosqueId'] as String?,
      recipientUid: json['recipientUid'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
      readBy: (json['readBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  bool isReadBy(String uid) => readBy.contains(uid);
}