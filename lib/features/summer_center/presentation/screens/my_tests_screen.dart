import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/summer_assignment.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_level.dart';
import '../../domain/entities/summer_subject.dart';
import '../providers/summer_assignment_provider.dart';
import '../providers/summer_center_provider.dart';
import '../providers/summer_level_provider.dart';
import '../providers/summer_subject_provider.dart';
import 'teacher_tests_list_screen.dart';

/// شاشة "اختباراتي" — نقطة دخول المعلمة إلى اختبارات المركز الصيفي.
///
/// تعتمد فقط على إسناداتها في summer_assignments، ولا تقرأ أو تفترض أي
/// شيء من assignedCircleIds أو حلقات التحفيظ المعتادة إطلاقاً — لو لم
/// تُسنَد المعلمة لأي (مستوى+مادة) في المركز الصيفي فلن ترى شيئاً هنا،
/// بصرف النظر عن حلقاتها المعتادة.
class MyTestsScreen extends ConsumerStatefulWidget {
  const MyTestsScreen({super.key});

  @override
  ConsumerState<MyTestsScreen> createState() => _MyTestsScreenState();
}

class _MyTestsScreenState extends ConsumerState<MyTestsScreen> {
  String? _selectedCenterId;
  String? _expandedLevelId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null || user.mosqueId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('اختباراتي')),
        body: Center(
          child: Text('لا يوجد مسجد مرتبط بحسابك', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
        ),
      );
    }

    final centersAsync = ref.watch(summerCentersByMosqueProvider(user.mosqueId!));

    return Scaffold(
      appBar: AppBar(title: const Text('اختباراتي')),
      body: centersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
        data: (allCenters) {
          final activeCenters = allCenters.where((c) => c.isActive).toList();
          if (activeCenters.isEmpty) {
            return _emptyState('لا يوجد مركز صيفي نشط حالياً', Icons.wb_sunny_outlined);
          }

          final current = activeCenters.firstWhere(
            (c) => c.id == _selectedCenterId,
            orElse: () => activeCenters.first,
          );

          if (!current.testsEnabledForTeachers) {
            return _emptyState(
              'شاشة الاختبارات معطَّلة حالياً من قبل مشرفة المركز',
              Icons.lock_outline_rounded,
            );
          }

          return Column(
            children: [
              if (activeCenters.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: DropdownButtonFormField<String>(
                    value: current.id,
                    decoration: const InputDecoration(labelText: 'المركز الصيفي'),
                    items: activeCenters
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontFamily: 'Tajawal'))))
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedCenterId = value;
                      _expandedLevelId = null;
                    }),
                  ),
                ),
              Expanded(child: _buildLevels(user.uid, user.name, current)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLevels(String teacherId, String teacherName, SummerCenter center) {
    final assignmentsAsync = ref.watch(
      summerAssignmentsByTeacherProvider(TeacherAssignmentsKey(centerId: center.id, teacherId: teacherId)),
    );
    final levels = ref.watch(activeSummerLevelsByCenterProvider(center.id));
    final subjects = ref.watch(activeSummerSubjectsByCenterProvider(center.id));

    return assignmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
      data: (assignments) {
        if (assignments.isEmpty) {
          return _emptyState('لم تُسنَد إليك أي مستويات أو مواد بعد', Icons.assignment_late_outlined);
        }

        final subjectIdsByLevel = <String, Set<String>>{};
        for (final a in assignments) {
          subjectIdsByLevel.putIfAbsent(a.levelId, () => {}).add(a.subjectId);
        }
        final myLevels = levels.where((l) => subjectIdsByLevel.containsKey(l.id)).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text(
              '${center.name} — تظهر هنا فقط المستويات والمواد التي أسندتها لك مشرفة المركز، وليست حلقات التحفيظ المعتادة.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade600, height: 1.7),
            ),
            const SizedBox(height: 16),
            for (final level in myLevels) ...[
              _LevelAccordionCard(
                level: level,
                subjectCount: subjectIdsByLevel[level.id]!.length,
                expanded: _expandedLevelId == level.id,
                onTap: () => setState(() => _expandedLevelId = _expandedLevelId == level.id ? null : level.id),
              ),
              if (_expandedLevelId == level.id)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Column(
                    children: subjects
                        .where((s) => subjectIdsByLevel[level.id]!.contains(s.id))
                        .map((subject) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SubjectTile(
                                subject: subject,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeacherTestsListScreen(
                                      center: center,
                                      level: level,
                                      subject: subject,
                                      teacherId: teacherId,
                                      teacherName: teacherName,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

class _LevelAccordionCard extends StatelessWidget {
  final SummerLevel level;
  final int subjectCount;
  final bool expanded;
  final VoidCallback onTap;

  const _LevelAccordionCard({
    required this.level,
    required this.subjectCount,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: expanded ? const Color(0xFFF3FAF4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: expanded ? AppTheme.primaryGreen : const Color(0xFFECECEC), width: expanded ? 1.8 : 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.child_care_rounded, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(level.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    subjectCount == 1 ? 'مادة واحدة مُسندة إليك' : (subjectCount == 2 ? 'مادتان مُسندتان إليك' : '$subjectCount مواد مُسندة إليك'),
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: expanded ? AppTheme.primaryGreen : const Color(0xFFC7C7C7)),
          ],
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final SummerSubject subject;
  final VoidCallback onTap;

  const _SubjectTile({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB8860B).withOpacity(0.4), width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0xFFFBF3E2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_stories_rounded, color: AppTheme.goldAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(subject.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppTheme.goldAccent),
          ],
        ),
      ),
    );
  }
}
