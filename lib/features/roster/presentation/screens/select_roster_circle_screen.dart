import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import 'roster_screen.dart';

/// شاشة اختيار الحلقة عند وجود أكثر من حلقة واحدة مُسندة للمعلمة.
///
/// تُعرض فقط عندما يكون لدى المعلمة أكثر من حلقة إجمالاً (عبر كل
/// المدارس/الدور المُسندة لها). كل دار تظهر كتسمية رمادية صغيرة تعلو
/// مجموعة بطاقات حلقاتها، مطابقةً للتصميم المعتمد.
class SelectRosterCircleScreen extends ConsumerWidget {
  const SelectRosterCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحلقة')),
      body: user == null || user.mosqueId == null
          ? Center(
              child: Text(
                'لم يتم تحديد مسجد لحسابك بعد',
                style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
              ),
            )
          : _buildGroups(context, ref, user.mosqueId!, user.assignedSchoolIds,
              user.assignedCircleIds),
    );
  }

  Widget _buildGroups(
    BuildContext context,
    WidgetRef ref,
    String mosqueId,
    List<String> assignedSchoolIds,
    List<String> assignedCircleIds,
  ) {
    // نراقب الـ Stream الخام مباشرة (وليس مزوّداً مشتقاً يُحوّل "لسا ما
    // وصلت البيانات" إلى قائمة فارغة)، حتى لا نُظهر رسالة "لا توجد
    // حلقات" خطأً بينما البيانات لا تزال في طريقها من Firestore.
    final schoolsAsync = ref.watch(schoolsByMosqueProvider(mosqueId));

    return schoolsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'تعذّر تحميل البيانات',
          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
        ),
      ),
      data: (allSchools) {
        // قائمة فارغة = لم يُسند لها شيء بعد، وليست إباحة لكل دور المسجد.
        final schools = allSchools
            .where((s) => s.isActive && assignedSchoolIds.contains(s.id))
            .toList();

        if (schools.isEmpty) {
          return Center(
            child: Text(
              'لا توجد حلقات مرتبطة بحسابك بعد',
              style:
                  TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: schools.length,
          itemBuilder: (context, index) {
            final school = schools[index];
            final circlesAsync =
                ref.watch(teachingCirclesBySchoolProvider(school.id));

            return circlesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (allCircles) {
                final circles = allCircles
                    .where((c) =>
                        c.isActive && assignedCircleIds.contains(c.id))
                    .toList();

                if (circles.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Text(
                          school.name,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      ...circles.map((circle) => _CircleCard(
                            circle: circle,
                            school: school,
                          )),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CircleCard extends StatelessWidget {
  final TeachingCircle circle;
  final School school;

  const _CircleCard({required this.circle, required this.school});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RosterScreen(
                circleId: circle.id,
                circleName: circle.name,
                schoolName: school.name,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppTheme.primaryGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    circle.name,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
