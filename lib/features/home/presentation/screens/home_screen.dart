import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/teacher_welcome_banner.dart';
import '../../../report_form/presentation/screens/my_reports_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../report_form/presentation/screens/attendance_report_screen.dart';
import '../../../roster/presentation/screens/roster_screen.dart';
import '../../../roster/presentation/screens/select_roster_circle_screen.dart';
import '../../../summer_center/presentation/screens/my_tests_screen.dart';
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        automaticallyImplyLeading: false,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(authProvider).user;
              final mosqueId = user?.mosqueId ?? '';
              final unreadCount =
                  ref.watch(unreadTeacherCountProvider(mosqueId));

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          height: size.height - MediaQuery.of(context).padding.top,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final teacherName = ref.watch(authProvider).user?.name;
                    if (teacherName == null || teacherName.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TeacherWelcomeBanner(name: teacherName),
                    );
                  },
                ),
                const Spacer(flex: 2),
                _buildHeader(context, theme, ref),
                const Spacer(flex: 3),
                _buildActionButtons(context, ref),
                const Spacer(flex: 1),
                _buildFooter(theme),
                
                const SizedBox(height: 10),
                Text(
                  'برمجة: صدام البريكي (أبو ود)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              width: 3,
            ),
          ),
          child: const Center(
            child: Text('📖', style: TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.appName,
          style: theme.textTheme.displayMedium?.copyWith(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.appSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          width: 60,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.goldAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.circleInfo),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
          label: const Text(AppStrings.newReport),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyReportsScreen()),
          ),
          icon: const Icon(Icons.history_rounded, size: 22),
          label: const Text(AppStrings.previousReports),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _onRosterPressed(context, ref),
          icon: const Icon(Icons.groups_rounded, size: 22),
          label: const Text('سجل الحلقة'),
        ),
       const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AttendanceReportScreen()),
          ),
          icon: const Icon(Icons.bar_chart_rounded, size: 22),
          label: const Text('تقرير الحضور والغياب'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyTestsScreen()),
          ),
          icon: const Icon(Icons.quiz_outlined, size: 22),
          label: const Text('اختباراتي (المركز الصيفي)'),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            size: 14,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            'يعمل بدون إنترنت',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// تحدّد وجهة زر "سجل الحلقة": دخول مباشر إن كان لدى المعلمة حلقة
  /// واحدة فقط إجمالاً (عبر كل مدارسها المُسندة)، أو شاشة اختيار حلقة
  /// إن كان لديها أكثر من واحدة، أو رسالة توضيحية إن لم توجد أي حلقة
  /// بعد — بنفس منطق الفلترة المُستخدم في شاشة بيانات الحلقة.
  ///
  /// نستخدم هنا انتظار البيانات الحقيقية (await على الـ Stream) بدل
  /// قراءتها فورياً، لأن القراءة الفورية قد تُرجع قائمة فارغة "مؤقتاً"
  /// إن لم تكن بيانات الدور/الحلقات قد وصلت بعد من Firestore (خاصة
  /// مباشرة بعد تسجيل الدخول، أو بعد تسجيل الخروج الذي يُبطل البيانات
  /// المخزّنة مؤقتاً) — وهذا كان يُظهر رسالة "لا يوجد سجل" خطأً رغم
  /// وجود حلقات فعلية، ريثما تصل البيانات في محاولة لاحقة.
  Future<void> _onRosterPressed(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.mosqueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حلقات مرتبطة بحسابك بعد')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final mosqueId = user.mosqueId!;
    final allMosqueSchools = await _loadActiveSchools(ref, mosqueId);
    // ملاحظة أمنية: قائمة فارغة تعني أنه لم يتم إسناد أي دار لهذه المعلمة
    // بعد من قِبل المشرفة، وليس معناها إباحة كل دور المسجد — لذلك لا يوجد
    // فرع "أظهري الكل" هنا.
    final schools = allMosqueSchools
        .where((s) => user.assignedSchoolIds.contains(s.id))
        .toList();

    final assignedCircles = <(String circleId, String circleName, String schoolName)>[];
    for (final school in schools) {
      final allSchoolCircles = await _loadActiveCircles(ref, school.id);
      final circles = allSchoolCircles
          .where((c) => user.assignedCircleIds.contains(c.id))
          .toList();
      for (final circle in circles) {
        assignedCircles.add((circle.id, circle.name, school.name));
      }
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // إغلاق مؤشر التحميل

    if (assignedCircles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حلقات مرتبطة بحسابك بعد')),
      );
    } else if (assignedCircles.length == 1) {
      final only = assignedCircles.first;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RosterScreen(
            circleId: only.$1,
            circleName: only.$2,
            schoolName: only.$3,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SelectRosterCircleScreen()),
      );
    }
  }

  /// يجلب الدور النشطة لمسجد معيّن، منتظراً وصول أول قيمة حقيقية من
  /// Firestore إن لم تكن قد وصلت بعد (بدل إرجاع قائمة فارغة مؤقتة).
  Future<List<School>> _loadActiveSchools(
      WidgetRef ref, String mosqueId) async {
    final current = ref.read(schoolsByMosqueProvider(mosqueId));
    final schools = current.hasValue
        ? current.value!
        : await ref.read(schoolsByMosqueProvider(mosqueId).future);
    return schools.where((s) => s.isActive).toList();
  }

  /// نفس الفكرة أعلاه، لكن لحلقات دار معيّنة.
  Future<List<TeachingCircle>> _loadActiveCircles(
      WidgetRef ref, String schoolId) async {
    final current = ref.read(teachingCirclesBySchoolProvider(schoolId));
    final circles = current.hasValue
        ? current.value!
        : await ref.read(teachingCirclesBySchoolProvider(schoolId).future);
    return circles.where((c) => c.isActive).toList();
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'قريباً',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          AppStrings.previousReportsComingSoon,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'حسناً',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }
}