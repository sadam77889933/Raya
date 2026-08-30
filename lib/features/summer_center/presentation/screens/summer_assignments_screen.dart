import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/teachers_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../domain/entities/summer_assignment.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_level.dart';
import '../../domain/entities/summer_subject.dart';
import '../providers/summer_assignment_provider.dart';
import '../providers/summer_center_provider.dart';
import '../providers/summer_level_provider.dart';
import '../providers/summer_subject_provider.dart';

/// توزيع المعلمات على (مستوى + مادة) داخل مركز صيفي واحد — الإسناد هنا
/// مستقل تماماً عن assignedCircleIds، ولا يُقرأ أو يُكتَب من/إلى وثيقة
/// المعلمة نفسها إطلاقاً؛ كل إسناد وثيقة مستقلة في summer_assignments.
class SummerAssignmentsScreen extends ConsumerWidget {
  final SummerCenter center;
  const SummerAssignmentsScreen({super.key, required this.center});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync =
        ref.watch(summerAssignmentsByCenterProvider(center.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('توزيع المعلمات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(center.name,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
          ),
        ),
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
        data: (assignments) {
          if (assignments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('لم تُسنَد أي معلمة بعد',
                        style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }

          final byTeacher = <String, List<SummerAssignment>>{};
          for (final a in assignments) {
            byTeacher.putIfAbsent(a.teacherId, () => []).add(a);
          }
          final teacherIds = byTeacher.keys.toList()
            ..sort((a, b) => byTeacher[a]!.first.teacherName.compareTo(byTeacher[b]!.first.teacherName));

          final levels = ref.watch(activeSummerLevelsByCenterProvider(center.id));
          final subjects = ref.watch(activeSummerSubjectsByCenterProvider(center.id));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
            itemCount: teacherIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final list = byTeacher[teacherIds[i]]!;
              return _TeacherAssignmentCard(
                teacherName: list.first.teacherName,
                assignments: list,
                levels: levels,
                subjects: subjects,
                onEdit: () => _openAssignSheet(
                  context,
                  ref,
                  preselectedTeacherId: list.first.teacherId,
                  preselectedTeacherName: list.first.teacherName,
                  allAssignments: assignments,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAssignSheet(context, ref, allAssignments: assignmentsAsync.value ?? const []),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إسناد جديد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _openAssignSheet(
    BuildContext context,
    WidgetRef ref, {
    String? preselectedTeacherId,
    String? preselectedTeacherName,
    required List<SummerAssignment> allAssignments,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignTeacherSheet(
        center: center,
        preselectedTeacherId: preselectedTeacherId,
        preselectedTeacherName: preselectedTeacherName,
        allAssignments: allAssignments,
      ),
    );
  }
}

class _TeacherAssignmentCard extends StatelessWidget {
  final String teacherName;
  final List<SummerAssignment> assignments;
  final List<SummerLevel> levels;
  final List<SummerSubject> subjects;
  final VoidCallback onEdit;

  const _TeacherAssignmentCard({
    required this.teacherName,
    required this.assignments,
    required this.levels,
    required this.subjects,
    required this.onEdit,
  });

  String _countLabel(int n) {
    if (n == 1) return 'إسناد واحد';
    if (n == 2) return 'إسنادان';
    return '$n إسنادات';
  }

  @override
  Widget build(BuildContext context) {
    final levelNameOf = {for (final l in levels) l.id: l.name};
    final subjectNameOf = {for (final s in subjects) s.id: s.name};

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.lightGreen,
                child: Text(
                  teacherName.isNotEmpty ? teacherName.substring(0, 1) : '؟',
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.primaryGreen, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacherName, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(_countLabel(assignments.length),
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.edit_rounded, size: 19, color: Colors.grey), onPressed: onEdit),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: assignments.map((a) {
              final lvl = levelNameOf[a.levelId] ?? '—';
              final subj = subjectNameOf[a.subjectId] ?? '—';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FAF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCFE9D3), width: 1.1),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: lvl, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.goldAccent)),
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: subj, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// ورقة سفلية لإسناد معلمة إلى مجموعة من أزواج (مستوى+مادة)، مع دعم إضافة
/// إسنادات جديدة وإزالة إسنادات قائمة معاً في عملية حفظ واحدة.
class _AssignTeacherSheet extends ConsumerStatefulWidget {
  final SummerCenter center;
  final String? preselectedTeacherId;
  final String? preselectedTeacherName;
  final List<SummerAssignment> allAssignments;

  const _AssignTeacherSheet({
    required this.center,
    this.preselectedTeacherId,
    this.preselectedTeacherName,
    required this.allAssignments,
  });

  @override
  ConsumerState<_AssignTeacherSheet> createState() => _AssignTeacherSheetState();
}

class _AssignTeacherSheetState extends ConsumerState<_AssignTeacherSheet> {
  String? _teacherId;
  String? _teacherName;
  final Set<String> _selectedKeys = {};
  Set<String> _initialKeys = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _teacherId = widget.preselectedTeacherId;
    _teacherName = widget.preselectedTeacherName;
    if (_teacherId != null) {
      _initialKeys = widget.allAssignments
          .where((a) => a.teacherId == _teacherId)
          .map((a) => '${a.levelId}|${a.subjectId}')
          .toSet();
      _selectedKeys.addAll(_initialKeys);
    }
  }

  Map<String, String> _existingAssignmentIdByKey() {
    return {
      for (final a in widget.allAssignments.where((a) => a.teacherId == _teacherId))
        '${a.levelId}|${a.subjectId}': a.id,
    };
  }

  Future<void> _save() async {
    if (_teacherId == null || _teacherName == null) return;
    setState(() => _saving = true);
    final repo = ref.read(summerCenterRepositoryProvider);
    final toAdd = _selectedKeys.difference(_initialKeys);
    final toRemove = _initialKeys.difference(_selectedKeys);
    final existingIds = _existingAssignmentIdByKey();

    try {
      if (toAdd.isNotEmpty) {
        await repo.addAssignmentsBulk(
          centerId: widget.center.id,
          mosqueId: widget.center.mosqueId,
          teacherId: _teacherId!,
          teacherName: _teacherName!,
          pairs: toAdd.map((k) {
            final parts = k.split('|');
            return {'levelId': parts[0], 'subjectId': parts[1]};
          }).toList(),
          existingKeys: _initialKeys,
        );

        // إشعار المعلمة بالمستوى/المادة الجديدة المُسندة إليها — فشل
        // الإشعار لا يجب أن يمنع نجاح الإسناد نفسه (نفس مبدأ
        // notifyReportCreated). كل الأزواج المُضافة في هذه الجلسة تُجمَع
        // في إشعار واحد بدل إشعار مستقل لكل زوج.
        try {
          final levels = ref.read(activeSummerLevelsByCenterProvider(widget.center.id));
          final subjects = ref.read(activeSummerSubjectsByCenterProvider(widget.center.id));
          final supervisorName = ref.read(authProvider).user?.name ?? 'المشرفة';
          final labels = toAdd.map((k) {
            final parts = k.split('|');
            final levelName = levels.where((l) => l.id == parts[0]).map((l) => l.name).firstOrNull ?? '';
            final subjectName = subjects.where((s) => s.id == parts[1]).map((s) => s.name).firstOrNull ?? '';
            return '$levelName - $subjectName';
          }).toList();
          await ref.read(notificationServiceProvider).notifySummerAssignmentCreated(
                teacherUid: _teacherId!,
                teacherName: _teacherName!,
                supervisorName: supervisorName,
                mosqueId: widget.center.mosqueId,
                levelSubjectLabels: labels,
              );
        } catch (_) {}
      }
      for (final key in toRemove) {
        final id = existingIds[key];
        if (id != null) {
          await repo.deleteAssignment(id);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(activeSummerLevelsByCenterProvider(widget.center.id));
    final subjects = ref.watch(activeSummerSubjectsByCenterProvider(widget.center.id));
    final teachersAsync = ref.watch(teachersByMosqueProvider(widget.center.mosqueId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text(
                  widget.preselectedTeacherId != null ? 'تعديل إسنادات $_teacherName' : 'إسناد معلمة جديدة',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                if (widget.preselectedTeacherId == null)
                  teachersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('تعذّر تحميل المعلمات', style: TextStyle(fontFamily: 'Tajawal')),
                    data: (teachers) {
                      final activeTeachers = teachers.where((t) => t.isActive).toList();
                      return DropdownButtonFormField<String>(
                        value: activeTeachers.any((t) => t.uid == _teacherId) ? _teacherId : null,
                        decoration: const InputDecoration(labelText: 'اختاري المعلمة'),
                        items: activeTeachers
                            .map((t) => DropdownMenuItem(value: t.uid, child: Text(t.name, style: const TextStyle(fontFamily: 'Tajawal'))))
                            .toList(),
                        onChanged: (value) {
                          final teacher = activeTeachers.firstWhere((t) => t.uid == value);
                          setState(() {
                            _teacherId = teacher.uid;
                            _teacherName = teacher.name;
                            _initialKeys = widget.allAssignments
                                .where((a) => a.teacherId == teacher.uid)
                                .map((a) => '${a.levelId}|${a.subjectId}')
                                .toSet();
                            _selectedKeys
                              ..clear()
                              ..addAll(_initialKeys);
                          });
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),
                if (_teacherId == null)
                  Expanded(
                    child: Center(
                      child: Text('اختاري معلمة أولاً لعرض المستويات والمواد',
                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                    ),
                  )
                else if (levels.isEmpty || subjects.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('أضيفي مستويات ومواد للمركز أولاً',
                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: levels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, li) {
                        final level = levels[li];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level.name,
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.goldAccent)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((subject) {
                                final key = '${level.id}|${subject.id}';
                                final selected = _selectedKeys.contains(key);
                                return FilterChip(
                                  label: Text(subject.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                                  selected: selected,
                                  selectedColor: AppTheme.lightGreen,
                                  checkmarkColor: AppTheme.primaryGreen,
                                  onSelected: (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedKeys.add(key);
                                      } else {
                                        _selectedKeys.remove(key);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (_teacherId == null || _saving) ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ الإسناد'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
