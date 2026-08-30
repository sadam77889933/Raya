import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_provider.dart';
import 'compose_notification_screen.dart';

/// شاشة موحّدة تعرض الإشعارات — تتصرف حسب دور المستخدم:
/// - المشرفة العامة: كل إشعارات "رفع تقرير" + زر إرسال رسالة
/// - مشرفة المسجد: إشعارات مسجدها فقط + زر إرسال رسالة (مقيّد لمسجدها)
/// - المعلمة: فقط الرسائل التوجيهية الموجَّهة لمسجدها، بدون زر إرسال
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final AsyncValue<List<AppNotification>> notificationsAsync;
    final bool canCompose;

    if (user.isSupervisor) {
      notificationsAsync = ref.watch(supervisorNotificationsProvider);
      canCompose = true;
    } else if (user.isMosqueSupervisor) {
      notificationsAsync =
          ref.watch(mosqueSupervisorNotificationsProvider(user.mosqueId ?? ''));
      canCompose = true;
    } else {
      notificationsAsync =
          ref.watch(teacherNotificationsProvider(user.mosqueId ?? ''));
      canCompose = false;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('حدث خطأ: $err')),
        data: (notifications) {
          // ملاحظة إصلاح: كان زر "إرسال رسالة للمعلمات" محشوراً داخل نفس
          // الفرع الذي يُبنى فقط عندما تكون القائمة غير فارغة — فإذا لم
          // تصل مشرفة المسجد بعد أي إشعار (مثلاً: مسجد جديد، أو لم تُرفَع
          // تقارير بعد)، كان يختفي `return Center(...)` المبكر الشاشة
          // بالكامل بلا أي زر إرسال، رغم أن صلاحيتها بالإرسال لا علاقة لها
          // بوجود إشعارات سابقة من عدمه. الإصلاح: زر الإرسال يُعرض دائماً
          // (إن كانت canCompose) بغضّ النظر عن حالة القائمة، وحالة "لا توجد
          // إشعارات" أصبحت مجرد محتوى بديل داخل المساحة القابلة للتمدد.
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_none_rounded,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد إشعارات حالياً',
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            final isUnread = !notif.isReadBy(user.uid);

                            return _NotificationCard(
                              notification: notif,
                              isUnread: isUnread,
                              onTap: () {
                                if (isUnread) {
                                  ref
                                      .read(notificationServiceProvider)
                                      .markAsRead(notif.id, user.uid);
                                }
                              },
                            );
                          },
                        ),
                ),
                if (canCompose) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ComposeNotificationScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.campaign_rounded, size: 20),
                      label: const Text('إرسال رسالة للمعلمات'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isUnread;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isUnread,
    required this.onTap,
  });

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  IconData get _icon {
    switch (notification.type) {
      case 'report_created':
        return Icons.description_rounded;
      case 'student_transfer':
        return Icons.compare_arrows_rounded;
      case 'summer_test_created':
        return Icons.quiz_rounded;
      case 'summer_assignment_created':
        return Icons.assignment_ind_rounded;
      case 'summer_test_reviewed':
        return Icons.rate_review_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color get _iconBgColor {
    switch (notification.type) {
      case 'report_created':
        return AppTheme.primaryGreen;
      case 'student_transfer':
        return AppTheme.goldAccent;
      case 'summer_test_created':
      case 'summer_assignment_created':
      case 'summer_test_reviewed':
        return AppTheme.goldAccent;
      default:
        return AppTheme.lightGreen;
    }
  }

  Color get _iconColor =>
      notification.type == 'custom_message' ? AppTheme.primaryGreen : Colors.white;

  @override
  Widget build(BuildContext context) {
    // "من: ..." يُعرض لكل الأنواع ما عدا الإشعارات التلقائية التي يكون
    // اسم الفاعلة مذكوراً أصلاً داخل نص الرسالة نفسه (رفع تقرير، أو إنشاء
    // اختبار في المركز الصيفي).
    final showSender = notification.type != 'report_created' &&
        notification.type != 'summer_test_created';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? AppTheme.lightGreen.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? AppTheme.primaryGreen.withOpacity(0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Stack(
          children: [
            if (isUnread)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, size: 17, color: _iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showSender
                            ? '${_timeAgo(notification.createdAt)} · من: ${notification.senderName}'
                            : _timeAgo(notification.createdAt),
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}