import 'package:hijri/hijri_calendar.dart';

/// رسالة مجدولة — تُرسَل تلقائياً عند فتح التطبيق في يوم هجري معيّن
/// (أو بعده)، مرة واحدة فقط لكل شهر هجري
class ScheduledNotification {
  final String id;
  final String title;
  final String body;
  final int hijriDayOfMonth; // 1-30
  final String? targetMosqueId; // null = كل المساجد
  final String senderName;
  final bool isActive;
  final String? lastSentHijriMonth; // "1448-02"
  final DateTime createdAt;

  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.hijriDayOfMonth,
    this.targetMosqueId,
    required this.senderName,
    required this.isActive,
    this.lastSentHijriMonth,
    required this.createdAt,
  });

  /// هل يجب إرسالها الآن؟ (اليوم الهجري تجاوز أو طابق يومها،
  /// ولم تُرسل هذا الشهر الهجري بعد)
  bool shouldSendNow(HijriCalendar today) {
    if (!isActive) return false;
    final currentHijriMonthKey =
        '${today.hYear}-${today.hMonth.toString().padLeft(2, '0')}';
    if (lastSentHijriMonth == currentHijriMonthKey) return false;
    return today.hDay >= hijriDayOfMonth;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'hijriDayOfMonth': hijriDayOfMonth,
        'targetMosqueId': targetMosqueId,
        'senderName': senderName,
        'isActive': isActive,
        'lastSentHijriMonth': lastSentHijriMonth,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScheduledNotification.fromJson(
      String id, Map<String, dynamic> json) {
    return ScheduledNotification(
      id: id,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      hijriDayOfMonth: json['hijriDayOfMonth'] as int? ?? 1,
      targetMosqueId: json['targetMosqueId'] as String?,
      senderName: json['senderName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      lastSentHijriMonth: json['lastSentHijriMonth'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}