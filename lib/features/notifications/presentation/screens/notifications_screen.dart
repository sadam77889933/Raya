import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/push_token_service.dart' show PushRegistrationResult;
import '../../../notifications/presentation/providers/push_token_provider.dart';
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
                _PushPermissionBanner(uid: user.uid),
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

/// بطاقة تفعيل إشعارات Push — تظهر مرة واحدة فقط أعلى الشاشة، وتختفي
/// نهائياً على هذا الجهاز بعد أول ضغطة على "تفعيل" (بغضّ النظر عن نتيجة
/// طلب الإذن: قبول أو رفض) أو إن كان الإذن ممنوحاً أصلاً. لا نافذة نظام
/// تلقائية عند فتح الشاشة — الإذن يُطلب فقط من ضغطة زر حقيقية، وهذا شرط
/// إلزامي لعمل الإشعارات على آيفون/آيباد.
class _PushPermissionBanner extends ConsumerStatefulWidget {
  final String uid;
  const _PushPermissionBanner({required this.uid});

  @override
  ConsumerState<_PushPermissionBanner> createState() =>
      _PushPermissionBannerState();
}

class _PushPermissionBannerState extends ConsumerState<_PushPermissionBanner> {
  bool _loading = false;
  bool? _dismissedOnThisDevice; // null = لم يُحمَّل بعد من التخزين المحلي

  static String _dismissKey(String uid) => 'push_banner_dismissed_$uid';

  @override
  void initState() {
    super.initState();
    _loadDismissedState();
  }

  Future<void> _loadDismissedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissedOnThisDevice = prefs.getBool(_dismissKey(widget.uid)) ?? false;
    });
  }

  Future<void> _markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey(widget.uid), true);
  }

  Future<void> _enablePush() async {
    setState(() => _loading = true);
    // نُخفي البطاقة نهائياً فقط عند نجاح التفعيل، أو عند رفض صريح للإذن من
    // المستخدمة (اختيارها). أي فشل تقني آخر (VAPID key، تعذّر جلب التوكن،
    // استثناء غير متوقع) لا يُخفي البطاقة — لتتمكن المستخدمة من إعادة
    // المحاولة لاحقاً بدل أن تختفي البطاقة نهائياً دون أن تعرف السبب.
    var shouldDismissPermanently = false;
    var showRetryMessage = false;
    try {
      final service = ref.read(pushTokenServiceProvider);
      final vapidKey = kIsWeb ? await service.getWebVapidKey() : null;
      final result = await service.requestPermissionAndRegister(
        uid: widget.uid,
        webVapidKey: vapidKey,
      );
      if (result == PushRegistrationResult.success ||
          result == PushRegistrationResult.permissionDenied) {
        shouldDismissPermanently = true;
      } else {
        showRetryMessage = true;
      }
    } catch (e) {
      // استثناء غير متوقع (شبكة، خدمات جوجل، إلخ) — لا نُخفي البطاقة، انظر
      // التوثيق أعلاه. نطبعه هنا (وليس فقط في resumeTokenSyncIfAlreadyGranted)
      // لأن هذا المسار تتفاعل معه المستخدمة مباشرة بضغطة زر، فمعرفة السبب
      // التقني الحقيقي من نافذة التشغيل (flutter run) أهم بكثير هنا.
      debugPrint('PushPermissionBanner._enablePush فشلت: $e');
      showRetryMessage = true;
    } finally {
      if (shouldDismissPermanently) await _markDismissed();
      if (mounted) {
        setState(() {
          _loading = false;
          if (shouldDismissPermanently) _dismissedOnThisDevice = true;
        });
        if (showRetryMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تعذّر تفعيل الإشعارات الآن، تحققي من الاتصال بالإنترنت '
                'وحاولي مرة أخرى',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedOnThisDevice == null || _dismissedOnThisDevice == true) {
      return const SizedBox.shrink();
    }

    final grantedAsync = ref.watch(notificationPermissionGrantedProvider);
    final alreadyGranted = grantedAsync.asData?.value ?? false;

    // إذن الإشعارات قد يكون ممنوحاً على مستوى النظام لكن تسجيل التوكن نفسه
    // فشل بصمت لسبب تقني (خدمات جوجل، شبكة، إلخ) — في هذه الحالة نُبقي
    // البطاقة ظاهرة بصياغة "أكملي التفعيل" بدل إخفائها نهائياً كأن كل شيء
    // تم، فتُتاح للمستخدمة فرصة حقيقية لإعادة المحاولة يدوياً.
    var needsRetryAfterGrant = false;
    if (alreadyGranted) {
      final hasTokenAsync =
          ref.watch(hasSavedPushTokenProvider(widget.uid));
      final hasToken = hasTokenAsync.asData?.value ?? true;
      if (hasToken) return const SizedBox.shrink();
      needsRetryAfterGrant = true;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.lightGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                needsRetryAfterGrant
                    ? 'الإذن ممنوح لكن تعذّر إكمال تفعيل الإشعارات — اضغطي لإعادة المحاولة'
                    : 'فعّلي إشعارات رعاية لتصلك الرسائل الجديدة حتى لو كان التطبيق مغلقاً',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : ElevatedButton(
                    onPressed: _enablePush,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      // لازم نُلغي الحد الأدنى العام لعرض الأزرار (مضبوط على
                      // double.infinity في الثيم العام لتصميم أزرار النماذج
                      // بعرض كامل) — وإلا فهذا الزر، داخل Row بلا Expanded،
                      // يحاول أن يكون بعرض لا نهائي فيفشل تخطيطه بصمت، ويظهر
                      // فقط خلفية البطاقة الخضراء دون أي محتوى على الإطلاق.
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'تفعيل',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ],
        ),
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
