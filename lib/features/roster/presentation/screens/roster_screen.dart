import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/roster_student.dart';
import '../providers/roster_provider.dart';
import '../widgets/roster_student_row.dart';

class RosterScreen extends ConsumerWidget {
  const RosterScreen({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'إضافة طالبة جديدة',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Tajawal'),
          decoration: const InputDecoration(hintText: 'اسم الطالبة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(rosterProvider.notifier).addStudent(name);
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, RosterStudent student) async {
    final controller = TextEditingController(text: student.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تعديل اسم الطالبة',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هذا التعديل يغيّر اسمها في التقارير القادمة فقط',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                labelText: 'اسم الطالبة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != student.name) {
      final updated = student.copyWith(name: newName);
      await ref.read(rosterProvider.notifier).updateStudent(updated);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rosterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الحلقة'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TextButton.icon(
              onPressed: () => _showAddDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة'),
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) =>
                        ref.read(rosterProvider.notifier).setSearchQuery(v),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        if (state.activeStudents.isNotEmpty) ...[
                          _sectionLabel('نشطة', state.activeStudents.length,
                              color: Colors.green.shade700),
                          const SizedBox(height: 6),
                          _groupCard(state.activeStudents, context, ref),
                          const SizedBox(height: 20),
                        ],
                        if (state.inactiveStudents.isNotEmpty) ...[
                          _sectionLabel(
                              'غير نشطة', state.inactiveStudents.length,
                              color: Colors.grey.shade500),
                          const SizedBox(height: 6),
                          _groupCard(state.inactiveStudents, context, ref),
                        ],
                        if (state.filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text(
                                'لا توجد نتائج',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, int count, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '$label · $count',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _groupCard(List students, BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: students.asMap().entries.map((entry) {
          final isLast = entry.key == students.length - 1;
          return RosterStudentRow(
            student: entry.value,
            isLast: isLast,
            onToggle: () =>
                ref.read(rosterProvider.notifier).toggleActive(entry.value),
            onEdit: () => _showEditDialog(context, ref, entry.value),
          );
        }).toList(),
      ),
    );
  }
}