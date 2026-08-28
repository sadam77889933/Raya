import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notification_service.dart';
import '../../domain/entities/app_notification.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// إشعارات المشرفة العامة (كل المساجد)
final supervisorNotificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  return ref
      .watch(notificationServiceProvider)
      .watchSupervisorNotifications();
});

/// إشعارات مشرفة مسجد (مسجدها فقط)
final mosqueSupervisorNotificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, mosqueId) {
  return ref
      .watch(notificationServiceProvider)
      .watchSupervisorNotifications(restrictToMosqueId: mosqueId);
});

/// إشعارات المعلمة (رسائل توجيهية لمسجدها + بث عام + إشعارات نقل طالبة
/// موجَّهة لها شخصياً بغض النظر عن مسجدها الحالي)
final teacherNotificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, mosqueId) {
  final uid = ref.watch(authProvider).user?.uid ?? '';
  return ref
      .watch(notificationServiceProvider)
      .watchTeacherNotifications(mosqueId: mosqueId, uid: uid);
});

/// عدد الإشعارات غير المقروءة (للمشرفة العامة)
final unreadSupervisorCountProvider = Provider<int>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;
  final notifsAsync = ref.watch(supervisorNotificationsProvider);
  return notifsAsync.when(
    data: (list) => list.where((n) => !n.isReadBy(user.uid)).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// عدد الإشعارات غير المقروءة (لمشرفة مسجد)
final unreadMosqueSupervisorCountProvider =
    Provider.family<int, String>((ref, mosqueId) {
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;
  final notifsAsync = ref.watch(mosqueSupervisorNotificationsProvider(mosqueId));
  return notifsAsync.when(
    data: (list) => list.where((n) => !n.isReadBy(user.uid)).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// عدد الإشعارات غير المقروءة (للمعلمة)
final unreadTeacherCountProvider = Provider.family<int, String>((ref, mosqueId) {
  final user = ref.watch(authProvider).user;
  if (user == null) return 0;
  final notifsAsync = ref.watch(teacherNotificationsProvider(mosqueId));
  return notifsAsync.when(
    data: (list) => list.where((n) => !n.isReadBy(user.uid)).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});