import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/summer_assignment.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_test.dart';
import '../providers/summer_assignment_provider.dart';
import '../providers/summer_level_provider.dart';
import '../providers/summer_subject_provider.dart';
import '../providers/summer_test_provider.dart';
import 'test_editor_screen.dart';

/// شاشة "اختبارات المعلمات" — مراجعة المشرفة لكل اختبارات مركز صيفي واحد
/// بفلاتر اختيارية (مستوى/مادة/معلمة). لا استعلام بلا نطاق مركز محدَّد
/// (centerId مُلزَم دائماً في summerTestsFilteredProvider).
class SupervisorTestsListScreen extends ConsumerStatefulWidget {
  final SummerCenter center;
  const SupervisorTestsListScreen({super.key, required this.center});

  @override
  ConsumerState<SupervisorTestsListScreen> createState() => _SupervisorTestsListScreenState();
}

class _SupervisorTestsListScreenState extends ConsumerState<SupervisorTestsListScreen> {
  String? _levelFilter;
  String? _subjectFilter;
  String? _teacherFilter;

  @override
  Widget build(BuildContext context) {
    final supervisor = ref.watch(authProvider).user;
    final levels = ref.watch(summerLevelsByCenterProvider(widget.center.id)).value ?? const [];
    final subjects = ref.watch(summerSubjectsByCenterProvider(widget.center.id)).value ?? const [];
    final assignments = ref.watch(summerAssignmentsByCenterProvider(widget.center.id)).value ?? const <SummerAssignment>[];

    final teachersById = <String, String>{};
    for (final a in assignments) {
      teachersById[a.teacherId] = a.teacherName;
    }

    final testsAsync = ref.watch(summerTestsFilteredProvider(SummerTestFilter(
      centerId: widget.center.id,
      levelId: _levelFilter,
      subjectId: _subjectFilter,
      teacherId: _teacherFilter,
    )));

    return Scaffold(
      appBar: AppBar(title: const Text('اختبارات المعلمات')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _levelFilter,
                          decoration: const InputDecoration(labelText: 'المستوى', isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('كل المستويات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                            for (final l in levels)
                              DropdownMenuItem(value: l.id, child: Text(l.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                          ],
                          onChanged: (value) => setState(() => _levelFilter = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _subjectFilter,
                          decoration: const InputDecoration(labelText: 'المادة', isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('كل المواد', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                            for (final s in subjects)
                              DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                          ],
                          onChanged: (value) => setState(() => _subjectFilter = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _teacherFilter,
                    decoration: const InputDecoration(labelText: 'المعلمة', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل المعلمات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                      for (final entry in teachersById.entries)
                        DropdownMenuItem(value: entry.key, child: Text(entry.value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                    ],
                    onChanged: (value) => setState(() => _teacherFilter = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: testsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
                data: (tests) {
                  if (tests.isEmpty) {
                    return Center(
                      child: Text('لا توجد اختبارات مطابقة', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tests.length == 1 ? 'اختبار واحد' : '${tests.length} اختبارات',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: tests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final test = tests[i];
                            final levelName = levels.where((l) => l.id == test.levelId).map((l) => l.name).firstOrNull ?? '';
                            final subjectName = subjects.where((s) => s.id == test.subjectId).map((s) => s.name).firstOrNull ?? '';
                            return _TestRow(
                              test: test,
                              levelName: levelName,
                              subjectName: subjectName,
                              onTap: () {
                                final level = levels.where((l) => l.id == test.levelId).firstOrNull;
                                final subject = subjects.where((s) => s.id == test.subjectId).firstOrNull;
                                if (level == null || subject == null || supervisor == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تعذّر فتح الاختبار', style: TextStyle(fontFamily: 'Tajawal'))),
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TestEditorScreen(
                                      testId: test.id,
                                      center: widget.center,
                                      level: level,
                                      subject: subject,
                                      currentUid: supervisor.uid,
                                      currentName: supervisor.name,
                                      isSupervisorView: true,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  final SummerTest test;
  final String levelName;
  final String subjectName;
  final VoidCallback onTap;

  const _TestRow({required this.test, required this.levelName, required this.subjectName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.title.isEmpty ? 'اختبار بلا عنوان' : test.title,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${test.teacherName} · $levelName · ${test.questionsCount} أسئلة',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Color(0xFFC7C7C7)),
          ],
        ),
      ),
    );
  }
}
