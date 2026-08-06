import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/roster_student.dart';
import '../providers/roster_provider.dart';
import '../providers/select_students_provider.dart';
import '../../../report_form/domain/entities/student_record.dart';
import '../../../report_form/presentation/providers/report_form_provider.dart';

class SelectStudentsScreen extends ConsumerStatefulWidget {
  const SelectStudentsScreen({super.key});

  @override
  ConsumerState<SelectStudentsScreen> createState() =>
      _SelectStudentsScreenState();
}

class _SelectStudentsScreenState extends ConsumerState<SelectStudentsScreen> {
  @override
  void initState() {
    super.initState();
    // إعادة ضبط الاختيار عند فتح الشاشة من جديد
    Future.microtask(() => ref.read(selectStudentsProvider.notifier).reset());
  }

  Future<void> _addNewStudent() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'طالبة جديدة',
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
      // تحديد الطالبة الجديدة تلقائياً بعد إضافتها
      final roster = ref.read(rosterProvider).students;
      final added = roster.firstWhere((s) => s.name == name.trim());
      ref.read(selectStudentsProvider.notifier).toggle(added.id);
    }
  }

  void _onNext(List<RosterStudent> allActive) {
    final selectedIds = ref.read(selectStudentsProvider).selectedIds;
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري طالبة واحدة على الأقل')),
      );
      return;
    }

    final selectedStudents =
        allActive.where((s) => selectedIds.contains(s.id)).toList();

    // بناء StudentRecord فارغ لكل طالبة مختارة، بالاسم جاهزاً
    final records = selectedStudents
        .asMap()
        .entries
        .map((e) => StudentRecord(
              index: e.key + 1,
              name: e.value.name,
              startSurah: '',
              endSurah: '',
              grade: '',
            ))
        .toList();

    ref.read(reportFormProvider.notifier).setStudentsFromRoster(records);
    context.push(AppRoutes.studentsTable);
  }

  @override
  Widget build(BuildContext context) {
    final rosterState = ref.watch(rosterProvider);
    final selectState = ref.watch(selectStudentsProvider);
    final notifier = ref.read(selectStudentsProvider.notifier);

    final activeStudents = rosterState.students
        .where((s) => s.isActive)
        .where((s) => selectState.searchQuery.trim().isEmpty
            ? true
            : s.name.contains(selectState.searchQuery.trim()))
        .toList();

    final selectedCount = selectState.selectedIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار الطالبات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: rosterState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حدّدي الطالبات المشمولات في تقرير هذا الشهر',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    onChanged: notifier.setSearchQuery,
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
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => selectedCount == activeStudents.length
                            ? notifier.clearAll()
                            : notifier.selectAll(activeStudents),
                        child: Row(
                          children: [
                            Icon(
                              selectedCount == activeStudents.length &&
                                      activeStudents.isNotEmpty
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            const Text('تحديد الكل',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                          ],
                        ),
                      ),
                      Text(
                        '$selectedCount من ${activeStudents.length} محددة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: activeStudents.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد طالبات نشطات في السجل',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                color: Colors.grey.shade400,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.builder(
                              itemCount: activeStudents.length,
                              itemBuilder: (context, index) {
                                final student = activeStudents[index];
                                final isSelected =
                                    selectState.selectedIds.contains(student.id);
                                final isLast = index == activeStudents.length - 1;

                                return InkWell(
                                  onTap: () => notifier.toggle(student.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.lightGreen
                                          : Colors.white,
                                      border: isLast
                                          ? null
                                          : Border(
                                              bottom: BorderSide(
                                                  color: Colors.grey.shade200)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_box_rounded
                                              : Icons.check_box_outline_blank_rounded,
                                          size: 20,
                                          color: isSelected
                                              ? AppTheme.primaryGreen
                                              : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            student.name,
                                            style: const TextStyle(
                                                fontFamily: 'Tajawal', fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () => _onNext(activeStudents),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    label: const Text('التالي'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _addNewStudent,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('إضافة طالبة غير موجودة في السجل'),
                  ),
                ],
              ),
            ),
    );
  }
}