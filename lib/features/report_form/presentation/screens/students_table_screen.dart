import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../providers/report_form_provider.dart';
import '../widgets/companion_curriculum_selector.dart';
import '../widgets/step_indicator.dart';
import '../widgets/student_form_card.dart';

class StudentsTableScreen extends ConsumerStatefulWidget {
  const StudentsTableScreen({super.key});

  @override
  ConsumerState<StudentsTableScreen> createState() =>
      _StudentsTableScreenState();
}

class _StudentsTableScreenState extends ConsumerState<StudentsTableScreen> {
  // -1 = كل البطاقات مطوية. بعد حفظ أي طالبة تُطوى كل البطاقات (بدل
  // فتح التالية تلقائياً)، فتختار المعلمة نفسها أي طالبة تريد تعبئتها
  // بعد ذلك بالضغط عليها — أبسط وأكثر موثوقية من محاولة تمرير الشاشة
  // تلقائياً لبطاقة معيّنة.
  int _expandedIndex = 0;

  void _onNext() {
    final state = ref.read(reportFormProvider);
    if (!state.allStudentsComplete) {
      _showIncompleteDialog();
      return;
    }
    context.push(AppRoutes.reportPreview);
  }

  void _showIncompleteDialog() {
    final state = ref.read(reportFormProvider);
    final completed = state.students.where((s) => s.isComplete).length;
    final total = state.circleInfo!.studentsCount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'بيانات غير مكتملة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'تم إدخال بيانات $completed من أصل $total طالبة.\nهل تريدين المتابعة مع الطالبات المُدخلات فقط؟',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'إكمال البيانات',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.reportPreview);
            },
            child: const Text(
              'متابعة',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportFormProvider);
    final studentsCount = state.students.length;
    final completedCount =
        state.students.where((s) => s.isComplete).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.studentsTableTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completedCount == studentsCount
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completedCount == studentsCount
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Text(
                  '$completedCount / $studentsCount',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: completedCount == studentsCount
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const StepIndicator(currentStep: 2, totalSteps: 4),
          LinearProgressIndicator(
            value: studentsCount > 0
                ? completedCount / studentsCount
                : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              completedCount == studentsCount
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
            ),
            minHeight: 3,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              // عنصر إضافي في الأعلى لقسم "المنهج المصاحب"، بدل أن يكون
              // ثابتاً خارج القائمة — هذا يجعل الشاشة كاملة قابلة للتمرير
              // معاً، فلا يحدث تجاوز (Overflow) عند ظهور لوحة المفاتيح
              // أثناء كتابة منهج جديد عبر "+ أخرى".
              itemCount: studentsCount + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CompanionCurriculumSelector(
                      selected:
                          state.circleInfo?.companionCurriculums ?? const [],
                      onChanged: (items) => ref
                          .read(reportFormProvider.notifier)
                          .setCompanionCurriculums(items),
                    ),
                  );
                }

                final listIndex = index - 1;
                final studentIndex = listIndex + 1;
                final student = state.students.length > listIndex
                    ? state.students[listIndex]
                    : null;

                return StudentFormCard(
                  studentIndex: studentIndex,
                  student: student,
                  isExpanded: _expandedIndex == listIndex,
                  onToggle: () {
                    setState(() {
                      _expandedIndex =
                          _expandedIndex == listIndex ? -1 : listIndex;
                    });
                  },
                  onSaved: (updatedStudent) {
                    ref
                        .read(reportFormProvider.notifier)
                        .updateStudent(studentIndex, updatedStudent);
                    // طي كل البطاقات دائماً بعد الحفظ — المعلمة تختار
                    // الطالبة التالية بنفسها من القائمة.
                    setState(() => _expandedIndex = -1);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _onNext,
              icon: const Icon(Icons.preview_rounded, size: 18),
              label: const Text('معاينة التقرير'),
            ),
          ),
        ],
      ),
    );
  }
}