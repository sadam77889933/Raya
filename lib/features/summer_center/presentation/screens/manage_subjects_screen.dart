import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_subject.dart';
import '../providers/summer_center_provider.dart';
import '../providers/summer_subject_provider.dart';

/// إدارة مواد مركز صيفي واحد — منفصلة تماماً عن أي منهج مصاحب في نظام
/// التقارير الشهرية المعتاد.
class ManageSubjectsScreen extends ConsumerStatefulWidget {
  final SummerCenter center;
  const ManageSubjectsScreen({super.key, required this.center});

  @override
  ConsumerState<ManageSubjectsScreen> createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends ConsumerState<ManageSubjectsScreen> {
  final _newNameController = TextEditingController();

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _add(int nextOrder) async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(summerCenterRepositoryProvider)
        .addSubject(widget.center.id, widget.center.mosqueId, name, nextOrder);
    _newNameController.clear();
  }

  Future<void> _editName(SummerSubject subject) async {
    final controller = TextEditingController(text: subject.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل اسم المادة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(summerCenterRepositoryProvider).updateSubjectName(subject.id, newName);
    }
  }

  Future<void> _confirmDeactivate(SummerSubject subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إخفاء هذه المادة؟', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        content: const Text(
          'لن تظهر بعد الآن للمعلمات عند إنشاء اختبار جديد، لكن اختباراتها السابقة تبقى محفوظة.',
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إخفاء'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(summerCenterRepositoryProvider).setSubjectActive(subject.id, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(summerSubjectsByCenterProvider(widget.center.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المواد'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.center.name,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المواد التي ستُدرَّس في هذا المركز',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            Expanded(
              child: subjectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return Center(
                      child: Text('لا توجد مواد بعد',
                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500)),
                    );
                  }
                  return ListView.separated(
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final subject = subjects[i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFBF3E2),
                            child: Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.goldAccent),
                          ),
                          title: Text(subject.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                          subtitle: subject.isActive
                              ? null
                              : const Text('مخفية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.orange)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_rounded, size: 19), onPressed: () => _editName(subject)),
                              if (subject.isActive)
                                IconButton(
                                  icon: const Icon(Icons.visibility_off_outlined, size: 19),
                                  onPressed: () => _confirmDeactivate(subject),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 19, color: AppTheme.primaryGreen),
                                  onPressed: () => ref.read(summerCenterRepositoryProvider).setSubjectActive(subject.id, true),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNameController,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(hintText: 'اسم المادة الجديدة...'),
                    onSubmitted: (_) => _add(subjectsAsync.value?.length ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldAccent,
                    minimumSize: const Size(52, 52),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _add(subjectsAsync.value?.length ?? 0),
                  child: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
