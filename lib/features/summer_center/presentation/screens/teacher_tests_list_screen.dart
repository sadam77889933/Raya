import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_level.dart';
import '../../domain/entities/summer_subject.dart';
import '../../domain/entities/summer_test.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../providers/summer_center_provider.dart';
import '../providers/summer_test_provider.dart';
import 'test_editor_screen.dart';

/// قائمة اختبارات معلمة واحدة ضمن (مستوى+مادة) محدَّدين — يمكن أن تحوي
/// أكثر من اختبار واحد لنفس (المستوى+المادة) بلا أي قيد (اختبار أول،
/// نهائي، تعويضي...)، كل واحد وثيقة summer_tests مستقلة.
class TeacherTestsListScreen extends ConsumerWidget {
  final SummerCenter center;
  final SummerLevel level;
  final SummerSubject subject;
  final String teacherId;
  final String teacherName;

  const TeacherTestsListScreen({
    super.key,
    required this.center,
    required this.level,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
  });

  Future<void> _createTest(BuildContext context, WidgetRef ref) async {
    final today = HijriCalendar.now();
    final hijriMonth = QuranConstants.hijriMonths[today.hMonth - 1];
    final hijriYear = '${today.hYear}';
    final repo = ref.read(summerCenterRepositoryProvider);
    final testId = await repo.addTest(
      centerId: center.id,
      mosqueId: center.mosqueId,
      levelId: level.id,
      subjectId: subject.id,
      teacherId: teacherId,
      teacherName: teacherName,
      title: 'اختبار جديد',
      hijriMonth: hijriMonth,
      hijriYear: hijriYear,
    );

    // إشعار تلقائي لمشرفات المسجد — فشل الإشعار لا يجب أن يمنع فتح شاشة
    // الاختبار الجديد الذي أُنشئ فعلاً (نفس مبدأ notifyReportCreated).
    try {
      await ref.read(notificationServiceProvider).notifySummerTestCreated(
            teacherName: teacherName,
            levelName: level.name,
            subjectName: subject.name,
            mosqueId: center.mosqueId,
          );
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestEditorScreen(
          testId: testId,
          center: center,
          level: level,
          subject: subject,
          currentUid: teacherId,
          currentName: teacherName,
          isSupervisorView: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(summerTeacherTestsProvider(
      TeacherTestsKey(teacherId: teacherId, levelId: level.id, subjectId: subject.id),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text('اختبارات ${subject.name}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(level.name, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
          ),
        ),
      ),
      body: testsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
        data: (tests) {
          if (tests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 46, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('لا توجد اختبارات بعد', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
            itemCount: tests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final test = tests[i];
              return _TestCard(
                test: test,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TestEditorScreen(
                      testId: test.id,
                      center: center,
                      level: level,
                      subject: subject,
                      currentUid: teacherId,
                      currentName: teacherName,
                      isSupervisorView: false,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTest(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('اختبار جديد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final SummerTest test;
  final VoidCallback onTap;

  const _TestCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.title.isEmpty ? 'اختبار بلا عنوان' : test.title,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          test.questionsCount == 1 ? 'سؤال واحد' : '${test.questionsCount} أسئلة',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${test.hijriMonth} ${test.hijriYear}هـ',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade400)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_rounded, size: 15, color: Color(0xFFC7C7C7)),
          ],
        ),
      ),
    );
  }
}
