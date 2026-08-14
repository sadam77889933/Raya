/// إشعار داخل التطبيق — نوعان:
/// 1. تلقائي: معلمة رفعت تقريراً (تراه المشرفات)
/// 2. رسالة يدوية: مشرفة تُرسل تذكيراً للمعلمات
class AppNotification {
  final String id;
  final String type; // 'report_created' | 'custom_message'
  final String audienceRole; // 'supervisor' | 'teacher'
  final String? targetMosqueId; // null = يشمل كل المساجد
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