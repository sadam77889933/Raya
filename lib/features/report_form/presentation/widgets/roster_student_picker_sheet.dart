import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../roster/domain/entities/roster_student.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../domain/entities/student_record.dart';
import '../../domain/services/available_roster_students.dart';

/// يعرض طالبات سجل الحلقة غير المضافات إلى التقرير، ويُرجع من اختارتهن
/// المعلمة (قائمة غير فارغة)، أو null إن أُغلقت الورقة دون اختيار.
Future<List<RosterStudent>?> showRosterStudentPickerSheet(
  BuildContext context, {
  required String circleId,
  required List<StudentRecord> currentStudents,
}) {
  return showModalBottomSheet<List<RosterStudent>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => RosterStudentPickerSheet(
      circleId: circleId,
      currentStudents: currentStudents,
    ),
  );
}

class RosterStudentPickerSheet extends ConsumerStatefulWidget {
  final String circleId;

  /// طالبات التقرير الحاليات (بما فيهن غير المحفوظات بعد) لاستبعادهن من القائمة.
  final List<StudentRecord> currentStudents;

  const RosterStudentPickerSheet({
    super.key,
    required this.circleId,
    required this.currentStudents,
  });

  @override
  ConsumerState<RosterStudentPickerSheet> createState() =>
      _RosterStudentPickerSheetState();
}

class _RosterStudentPickerSheetState
    extends ConsumerState<RosterStudentPickerSheet> {
  final Set<String> _selectedIds = {};
  String _query = '';

  void _toggle(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _confirm(List<RosterStudent> available) {
    final picked =
        available.where((s) => _selectedIds.contains(s.id)).toList();
    Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rosterState = ref.watch(rosterProvider(widget.circleId));
    final available = rosterStudentsNotInReport(
      roster: rosterState.students,
      reportStudents: widget.currentStudents,
    );
    final visible = searchRosterStudents(available, _query);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختيار طالبات من سجل الحلقة',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'تظهر هنا الطالبات غير المضافات في هذا التقرير',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحثي باسم الطالبة...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildList(
                  isLoading: rosterState.isLoading,
                  rosterIsEmpty: rosterState.students.isEmpty,
                  available: available,
                  visible: visible,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    _selectedIds.isEmpty ? null : () => _confirm(available),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'اختاري طالبة واحدة على الأقل'
                      : 'إضافة (${_selectedIds.length})',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required bool isLoading,
    required bool rosterIsEmpty,
    required List<RosterStudent> available,
    required List<RosterStudent> visible,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (available.isEmpty) {
      return _EmptyMessage(
        rosterIsEmpty
            ? 'سجل هذه الحلقة فارغ'
            : 'كل طالبات السجل مضافات في هذا التقرير',
      );
    }
    if (visible.isEmpty) {
      return const _EmptyMessage('لا توجد نتائج مطابقة للبحث');
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: visible.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final student = visible[index];
          return CheckboxListTile(
            value: _selectedIds.contains(student.id),
            onChanged: (_) => _toggle(student.id),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppTheme.primaryGreen,
            title: Text(student.name),
            subtitle: student.isActive ? null : const Text('غير نشطة'),
          );
        },
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String message;

  const _EmptyMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500),
      ),
    );
  }
}
