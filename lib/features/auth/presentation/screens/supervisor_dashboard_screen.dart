import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/screens/manage_mosques_screen.dart';
import '../providers/auth_provider.dart';
import 'create_teacher_screen.dart';
import 'manage_teachers_screen.dart';
import '../../../report_form/presentation/screens/all_reports_screen.dart';
import '../../../pdf_export/presentation/screens/merge_reports_screen.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

class SupervisorDashboardScreen extends ConsumerWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المشرفة'),
        actions: [
          Builder(
            builder: (context) {
              final unreadCount = ref.watch(unreadSupervisorCountProvider);
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
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Padding(
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
            const SizedBox(height: 4),
            Text(
              'إدارة الحلقات والمعلمات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),

            _DashboardCard(
              icon: Icons.person_add_rounded,
              title: 'إنشاء حساب معلمة',
              subtitle: 'أضيفي معلمة جديدة وحدّدي مسجدها',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateTeacherScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            _DashboardCard(
              icon: Icons.mosque_rounded,
              title: 'إدارة المساجد',
              subtitle: 'أضيفي مساجد جديدة أو فعّلي/عطّلي مسجداً',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageMosquesScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DashboardCard(
              icon: Icons.people_alt_rounded,
              title: 'إدارة المعلمات',
              subtitle: 'عرض المعلمات، تفعيل أو تعطيل حساباتهن',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageTeachersScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            _DashboardCard(
              icon: Icons.description_rounded,
              title: 'جميع التقارير',
              subtitle: 'عرض والبحث في تقارير كل المساجد',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AllReportsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DashboardCard(
              icon: Icons.merge_type_rounded,
              title: 'تصدير تقارير مُدمَجة',
              subtitle: 'دمج تقارير كل معلمات مسجد في ملف PDF واحد',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MergeReportsScreen(),
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
                  icon,
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