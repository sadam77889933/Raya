import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/circle_info.dart';
import '../../domain/entities/student_record.dart';
import '../providers/report_form_provider.dart';
import '../widgets/step_indicator.dart';

class ReportPreviewScreen extends ConsumerWidget {
  const ReportPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportFormProvider);
    final info = state.circleInfo!;
    final students =
        state.students.where((s) => s.isComplete).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.previewTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const StepIndicator(currentStep: 3, totalSteps: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.previewSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CircleInfoCard(info: info),
                  const SizedBox(height: 16),
                  _StudentsPreviewCard(students: students),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.pdfExport),
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      size: 20),
                  label: const Text(AppStrings.createPdf),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(AppStrings.editData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleInfoCard extends StatelessWidget {
  final CircleInfo info;
  const _CircleInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text('بيانات الحلقة',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'المعلمة', value: info.teacherName),
            _InfoRow(label: 'الحلقة', value: info.circleName),
            _InfoRow(label: 'المسجد', value: info.mosqueName),
            _InfoRow(
                label: 'الشهر',
                value: '${info.month} ${info.year}'),
            _InfoRow(
              label: 'عدد الطالبات',
              value: '${info.studentsCount} طالبة',
              isLast: info.companionCurriculums.isEmpty,
            ),
            if (info.companionCurriculums.isNotEmpty)
              _InfoRow(
                label: 'المنهج المصاحب',
                value: info.companionCurriculums.join(' + '),
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}

class _StudentsPreviewCard extends StatelessWidget {
  final List<StudentRecord> students;
  const _StudentsPreviewCard({required this.students});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text('الطالبات (${students.length})',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...students.asMap().entries.map(
                  (e) => _StudentPreviewRow(
                    index: e.key + 1,
                    student: e.value,
                    isLast: e.key == students.length - 1,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StudentPreviewRow extends StatelessWidget {
  final int index;
  final StudentRecord student;
  final bool isLast;

  const _StudentPreviewRow({
    required this.index,
    required this.student,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  student.name,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  student.grade,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (student.wasAbsent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'غ${student.absenceDays}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}