import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/student_record.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';

class StudentFormCard extends StatefulWidget {
  final int studentIndex;
  final StudentRecord? student;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(StudentRecord) onSaved;

  const StudentFormCard({
    super.key,
    required this.studentIndex,
    required this.student,
    required this.isExpanded,
    required this.onToggle,
    required this.onSaved,
  });

  @override
  State<StudentFormCard> createState() => _StudentFormCardState();
}

class _StudentFormCardState extends State<StudentFormCard> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _absenceDaysController;
  late final TextEditingController _attendanceDaysController;
  late final TextEditingController _notesController;
  late final TextEditingController _behaviorController;

  String? _startSurah;
  String? _endSurah;
  String? _grade;
  String? _reviewStartSurah;
  String? _reviewEndSurah;
  String? _reviewGrade;
  String? _absenceReason;
  String? _companionCurriculum;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?.name ?? '');
    _absenceDaysController = TextEditingController(
      text: (s?.absenceDays ?? 0) > 0 ? '${s!.absenceDays}' : '',
    );
    _attendanceDaysController = TextEditingController(
      text: (s?.attendanceDays ?? 0) > 0 ? '${s!.attendanceDays}' : '',
    );
    _notesController = TextEditingController(text: s?.notes ?? '');
    _behaviorController =
        TextEditingController(text: '${s?.behaviorScore ?? 10}');
    _startSurah = s?.startSurah.isNotEmpty == true ? s!.startSurah : null;
    _endSurah = s?.endSurah.isNotEmpty == true ? s!.endSurah : null;
    _grade = s?.grade.isNotEmpty == true ? s!.grade : null;
    _reviewStartSurah = s?.reviewStartSurah.isNotEmpty == true ? s!.reviewStartSurah : null;
    _reviewEndSurah = s?.reviewEndSurah.isNotEmpty == true ? s!.reviewEndSurah : null;
    _reviewGrade = s?.reviewGrade.isNotEmpty == true ? s!.reviewGrade : null;
    _absenceReason = s?.absenceReason.isNotEmpty == true ? s!.absenceReason : null;
    _companionCurriculum = s?.companionCurriculum.isNotEmpty == true ? s!.companionCurriculum : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _absenceDaysController.dispose();
    _behaviorController.dispose();
    _attendanceDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isComplete => widget.student?.isComplete == true;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSaved(StudentRecord(
      index: widget.studentIndex,
      name: _nameController.text.trim(),
      startSurah: _startSurah ?? '',
      endSurah: _endSurah ?? '',
      grade: _grade ?? '',
      behaviorScore: int.tryParse(_behaviorController.text.trim()) ?? 10,
      reviewStartSurah: _reviewStartSurah ?? _startSurah ?? '',
      reviewEndSurah: _reviewEndSurah ?? _endSurah ?? '',
      reviewGrade: _reviewGrade ?? _grade ?? '',
      attendanceDays: int.tryParse(_attendanceDaysController.text.trim()) ?? 0,
      absenceDays: int.tryParse(_absenceDaysController.text.trim()) ?? 0,
      absenceReason: _absenceReason ?? '',
      companionCurriculum: _companionCurriculum ?? '',
      notes: _notesController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isComplete
                          ? AppTheme.primaryGreen
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isComplete
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : Text(
                              '${widget.studentIndex}',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student?.name.isNotEmpty == true
                              ? widget.student!.name
                              : 'الطالبة ${widget.studentIndex}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: widget.student?.name.isNotEmpty == true
                                ? theme.colorScheme.onSurface
                                : Colors.grey.shade400,
                          ),
                        ),
                        if (_isComplete && widget.student != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'حفظ: ${widget.student!.startSurah} ← ${widget.student!.endSurah}  |  ${widget.student!.grade}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final absenceDays = int.tryParse(_absenceDaysController.text) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            AppTextField(
              label: AppStrings.studentName,
              hint: AppStrings.studentNameHint,
              controller: _nameController,
              isRequired: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _sectionLabel('الحفظ'),
           const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'التقدير',
              hint: 'التقدير',
              value: _grade,
              items: QuranConstants.grades,
              itemLabel: (g) => g,
              isRequired: true,
              onChanged: (v) => setState(() => _grade = v),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: AppSearchableDropdown(
                  label: 'من سورة',
                  hint: 'اختاري',
                  value: _startSurah,
                  items: QuranConstants.surahs,
                  isRequired: true,
                  onChanged: (v) => setState(() => _startSurah = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppSearchableDropdown(
                  label: 'إلى سورة',
                  hint: 'اختاري',
                  value: _endSurah,
                  items: QuranConstants.surahs,
                  isRequired: true,
                  onChanged: (v) => setState(() => _endSurah = v),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _sectionLabel('المراجعة'),
            const SizedBox(height: 8),
            AppDropdownField<String>(
              label: 'التقدير',
              hint: 'التقدير',
              value: _reviewGrade,
              items: QuranConstants.grades,
              itemLabel: (g) => g,
              isRequired: true,
              onChanged: (v) => setState(() => _reviewGrade = v),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: AppSearchableDropdown(
                  label: 'من سورة',
                  hint: 'اختاري',
                  value: _reviewStartSurah,
                  items: QuranConstants.surahs,
                  isRequired: true,
                  onChanged: (v) => setState(() => _reviewStartSurah = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppSearchableDropdown(
                  label: 'إلى سورة',
                  hint: 'اختاري',
                  value: _reviewEndSurah,
                  items: QuranConstants.surahs,
                  isRequired: true,
                  onChanged: (v) => setState(() => _reviewEndSurah = v),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _sectionLabel('السلوك والانضباط'),
            const SizedBox(height: 8),
            AppTextField(
              label: 'الدرجة من 10',
              hint: '10',
              controller: _behaviorController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final n = int.tryParse(v);
                if (n == null || n < 0 || n > 10) return 'من 0 إلى 10';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _sectionLabel('الحضور والغياب'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: AppTextField(
                  label: 'أيام الحضور',
                  hint: '0',
                  controller: _attendanceDaysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  label: 'أيام الغياب',
                  hint: '0',
                  controller: _absenceDaysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            if (absenceDays > 0) ...[
              const SizedBox(height: 8),
              AppDropdownField<String>(
                label: 'سبب الغياب',
                hint: 'اختاري السبب',
                value: _absenceReason,
                items: QuranConstants.absenceReasons,
                itemLabel: (r) => r,
                onChanged: (v) => setState(() => _absenceReason = v),
              ),
            ],
            const SizedBox(height: 14),
            AppDropdownField<String>(
              label: 'المنهج المصاحب',
              hint: 'اختياري',
              value: _companionCurriculum,
              items: QuranConstants.companionCurriculums,
              itemLabel: (c) => c,
              onChanged: (v) => setState(() => _companionCurriculum = v),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: AppStrings.notes,
              hint: AppStrings.notesHint,
              controller: _notesController,
              maxLines: 2,
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('حفظ بيانات الطالبة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }
}