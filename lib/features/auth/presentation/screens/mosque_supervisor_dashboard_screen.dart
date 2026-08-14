import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../pdf_export/presentation/screens/merge_reports_screen.dart';
import '../../../report_form/presentation/screens/all_reports_screen.dart';
import '../../../mosques/presentation/screens/manage_mosques_screen.dart';
import '../../../mosques/presentation/screens/mosque_branding_screen.dart';
import '../providers/auth_provider.dart';
import 'create_teacher_screen.dart';
import 'manage_teachers_screen.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../notifications/presentation/screens/manage_scheduled_notifications_screen.dart';
import '../../../report_form/presentation/screens/attendance_report_screen.dart';
class MosqueSupervisorDashboardScreen extends ConsumerWidget {
  const MosqueSupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName = user?.name ?? '';
    final mosqueId = user?.mosqueId;

    final mosques = ref.watch(activeMosquesProvider);
    final mosque = mosques.where((m) => m.id == mosqueId).firstOrNull;
    final mosqueName = mosque?.name ?? 'غير محدد';

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة مشرفة المسجد'),
        actions: [
          if (mosqueId != null)
            Builder(
              builder: (context) {
                final unreadCount =
                    ref.watch(unreadMosqueSupervisorCountProvider(mosqueId));
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
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
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
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أهلاً بك، $userName',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mosque_rounded,
                      size: 13, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    mosqueName,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (mosqueId != null) ...[
              _DashboardCard(
                icon: Icons.person_add_rounded,
                title: 'إنشاء حساب معلمة',
                subtitle: 'تُضاف مباشرة لمسجدك، بدون اختيار مسجد آخر',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateTeacherScreen(lockedMosqueId: mosqueId),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _DashboardCard(
                icon: Icons.people_alt_rounded,
                title: 'معلمات مسجدي',
                subtitle: 'عرض وتفعيل/تعطيل معلمات مسجدك فقط',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageTeachersScreen(restrictToMosqueId: mosqueId),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _DashboardCard(
                icon: Icons.description_rounded,
                title: 'تقارير مسجدي',
                subtitle: 'عرض تقارير معلمات مسجدك فقط',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AllReportsScreen(restrictToMosqueId: mosqueId),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _DashboardCard(
                icon: Icons.merge_type_rounded,
                title: 'تصدير تقارير مُدمَجة',
                subtitle: 'ملف واحد يجمع تقارير كل معلمات مسجدك',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MergeReportsScreen(restrictToMosqueId: mosqueId),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _DashboardCard(
                icon: Icons.bar_chart_rounded,
                title: 'تقرير الحضور والغياب',
                subtitle: 'ملخّص غياب طالبات مسجدك عبر فترة زمنية',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AttendanceReportScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _DashboardCard(
                icon: Icons.mosque_rounded,
                title: 'الدور والحلقات',
                subtitle: 'إضافة وتعديل الدور والحلقات التابعة لمسجدك فقط',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageMosquesScreen(restrictToMosqueId: mosqueId),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _DashboardCard(
                icon: Icons.image_outlined,
                title: 'بيانات المسجد',
                subtitle: 'الختم واسم مشرفة الحلقات اللذان يظهران في التقرير',
                onTap: mosque == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MosqueBrandingScreen(mosque: mosque),
                          ),
                        ),
              ),
              const SizedBox(height: 14),
            ],
              _DashboardCard(
                icon: Icons.calendar_month_rounded,
                title: 'الرسائل المجدولة',
                subtitle: 'رسائل تذكيرية لمعلمات مسجدك كل شهر هجري',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ManageScheduledNotificationsScreen(),
                  ),
                ),
              ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                'برمجة: صدام البريكي (أبو ود)',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isComingSoon;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isComingSoon
                      ? Colors.grey.shade100
                      : AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComingSoon ? Icons.lock_outline_rounded : icon,
                  color: isComingSoon
                      ? Colors.grey.shade400
                      : AppTheme.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isComingSoon
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isComingSoon)
                Icon(Icons.arrow_back_ios_rounded,
                    size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}