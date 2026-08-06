import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../roster/presentation/screens/select_students_screen.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/circle_info.dart';
import '../providers/report_form_provider.dart';
import '../widgets/step_indicator.dart';

class CircleInfoScreen extends ConsumerStatefulWidget {
  const CircleInfoScreen({super.key});

  @override
  ConsumerState<CircleInfoScreen> createState() => _CircleInfoScreenState();
}

class _CircleInfoScreenState extends ConsumerState<CircleInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _teacherNameController;
  late final TextEditingController _circleNameController;
  late final TextEditingController _mosqueNameController;
  late final TextEditingController _schoolNameController;
  late final TextEditingController _yearController;
  late final TextEditingController _studentsCountController;

  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    final savedInfo = ref.read(reportFormProvider).circleInfo;
    _teacherNameController =
        TextEditingController(text: savedInfo?.teacherName ?? '');
    _circleNameController =
        TextEditingController(text: savedInfo?.circleName ?? '');
    _mosqueNameController =
        TextEditingController(text: savedInfo?.mosqueName ?? '');
        _schoolNameController =
        TextEditingController(text: savedInfo?.schoolName ?? '');
    _yearController =
        TextEditingController(text: savedInfo?.year ?? '');
    _studentsCountController = TextEditingController(
      text: savedInfo?.studentsCount.toString() ?? '',
    );
    _selectedMonth = savedInfo?.month;
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _circleNameController.dispose();
    _mosqueNameController.dispose();
    _schoolNameController.dispose();
    _yearController.dispose();
    _studentsCountController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (!_formKey.currentState!.validate()) return;

    final info = CircleInfo(
      teacherName: _teacherNameController.text.trim(),
      circleName: _circleNameController.text.trim(),
      mosqueName: _mosqueNameController.text.trim(),
      schoolName: _schoolNameController.text.trim(),
      month: _selectedMonth!,
      year: _yearController.text.trim(),
      studentsCount: 0,
    );

    ref.read(reportFormProvider.notifier).saveCircleInfo(info);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SelectStudentsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.circleInfoTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const StepIndicator(currentStep: 1, totalSteps: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.circleInfoSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      label: AppStrings.teacherName,
                      hint: AppStrings.teacherNameHint,
                      controller: _teacherNameController,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: AppStrings.circleName,
                      hint: AppStrings.circleNameHint,
                      controller: _circleNameController,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: AppStrings.mosqueName,
                      hint: AppStrings.mosqueNameHint,
                      controller: _mosqueNameController,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'مدرسة / دار',
                      hint: 'مثال: حفصة رضي الله عنها',
                      controller: _schoolNameController,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppDropdownField<String>(
                            label: AppStrings.month,
                            hint: AppStrings.selectMonth,
                            value: _selectedMonth,
                            items: QuranConstants.hijriMonths,
                            itemLabel: (m) => m,
                            isRequired: true,
                            onChanged: (val) {
                              setState(() => _selectedMonth = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            label: AppStrings.year,
                            hint: AppStrings.yearHint,
                            controller: _yearController,
                            isRequired: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppStrings.fieldRequired;
                              }
                              final year = int.tryParse(val);
                              if (year == null ||
                                  year < 1400 ||
                                  year > 1500) {
                                return AppStrings.invalidYear;
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    
                   const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _onNext,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              label: const Text(AppStrings.next),
            ),
          ),
        ],
      ),
    );
  }
}