import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scheduled_notification_service.dart';
import '../../domain/entities/scheduled_notification.dart';

final scheduledNotificationServiceProvider =
    Provider<ScheduledNotificationService>(
  (ref) => ScheduledNotificationService(),
);

/// كل الرسائل المجدولة (للمشرفة العامة) أو المُقيَّدة بمسجد (لمشرفة المسجد)
final scheduledNotificationsProvider = StreamProvider.family<
    List<ScheduledNotification>, String?>((ref, restrictToMosqueId) {
  return ref
      .watch(scheduledNotificationServiceProvider)
      .watchAll(restrictToMosqueId: restrictToMosqueId);
});