import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../roster/presentation/screens/select_students_screen.dart';
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

  String? _selectedSchoolId;
  String? _selectedCircleId;

  String? _selectedMonth;
  String? _selectedYear;

  static const List<String> _hijriMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  @override
  void initState() {
    super.initState();

    final savedInfo = ref.read(reportFormProvider).circleInfo;

    if (savedInfo != null) {
      _selectedMonth = savedInfo.month;
      _selectedYear = savedInfo.year;
    } else {
      final today = HijriCalendar.now();
      _selectedMonth = _hijriMonths[today.hMonth - 1];
      _selectedYear = today.hYear.toString();
    }
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSchoolId == null || _selectedCircleId == null) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    List<dynamic> mosques = ref.read(activeMosquesProvider);
    if (mosques.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        mosques = ref.read(activeMosquesProvider);
        if (mosques.isNotEmpty) break;
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    final mosqueName = mosques
            .where((m) => m.id == user.mosqueId)
            .map((m) => m.name)
            .firstOrNull ??
        '';

    final allMosqueSchools =
        ref.read(activeSchoolsByMosqueProvider(user.mosqueId ?? ''));
    final schools = user.assignedSchoolIds.isEmpty
        ? allMosqueSchools
        : allMosqueSchools
            .where((s) => user.assignedSchoolIds.contains(s.id))
            .toList();
    final schoolName = schools
            .where((s) => s.id == _selectedSchoolId)
            .map((s) => s.name)
            .firstOrNull ??
        '';

    final allSchoolCircles =
        ref.read(activeTeachingCirclesBySchoolProvider(_selectedSchoolId!));
    final circles = user.assignedCircleIds.isEmpty
        ? allSchoolCircles
        : allSchoolCircles
            .where((c) => user.assignedCircleIds.contains(c.id))
            .toList();
    final circleName = circles
            .where((c) => c.id == _selectedCircleId)
            .map((c) => c.name)
            .firstOrNull ??
        '';

    final info = CircleInfo(
      teacherName: user.name,
      circleName: circleName,
      mosqueName: mosqueName,
      schoolName: schoolName,
      month: _selectedMonth!,
      year: _selectedYear!,
      studentsCount: 0,
    );

    ref.read(reportFormProvider.notifier).saveCircleInfo(info);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SelectStudentsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

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
                    const SizedBox(height: 20),

                    if (user != null) _ReadOnlyInfoCard(user: user),
                    const SizedBox(height: 20),

                    if (user?.mosqueId != null)
                      _buildSchoolAndCircleDropdowns(user!)
                    else
                      Text(
                        'لم يتم تحديد مسجد لحسابك بعد، تواصلي مع المشرفة',
                        style: TextStyle(
                            fontFamily: 'Tajawal', color: Colors.red.shade400),
                      ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildAutoFilledDropdown(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildAutoFilledYearField(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'مُعبَّأ تلقائياً بالشهر الحالي — يمكنك تغييره',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.5,
                              color: Colors.grey.shade500,
                            ),
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

  Widget _buildSchoolAndCircleDropdowns(UserModel user) {
    final mosqueId = user.mosqueId!;
    final allMosqueSchools = ref.watch(activeSchoolsByMosqueProvider(mosqueId));
    final schools = user.assignedSchoolIds.isEmpty
        ? allMosqueSchools
        : allMosqueSchools
            .where((s) => user.assignedSchoolIds.contains(s.id))
            .toList();

    // اختيار الدار تلقائياً إن لم يكن أمامها إلا خيار واحد فقط
    if (_selectedSchoolId == null && schools.length == 1) {
      _selectedSchoolId = schools.first.id;
    }

    final allSchoolCircles = _selectedSchoolId == null
        ? const <TeachingCircle>[]
        : ref.watch(activeTeachingCirclesBySchoolProvider(_selectedSchoolId!));
    final circles = user.assignedCircleIds.isEmpty
        ? allSchoolCircles
        : allSchoolCircles
            .where((c) => user.assignedCircleIds.contains(c.id))
            .toList();

    // اختيار الحلقة تلقائياً إن لم يكن أمامها إلا خيار واحد فقط
    if (_selectedCircleId == null && circles.length == 1) {
      _selectedCircleId = circles.first.id;
    }

    if (schools.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          'لا توجد دور/مدارس مضافة لمسجدك بعد، تواصلي مع المشرفة العامة لإضافتها',
          style: TextStyle(
              fontFamily: 'Tajawal', fontSize: 12, color: Colors.orange.shade800),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedSchoolId,
          decoration: InputDecoration(
            labelText: 'الدار / المدرسة *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: schools
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name,
                        style: const TextStyle(fontFamily: 'Tajawal')),
                  ))
              .toList(),
          onChanged: (val) => setState(() {
            _selectedSchoolId = val;
            _selectedCircleId = null;
          }),
          validator: (val) => val == null ? AppStrings.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCircleId,
          decoration: InputDecoration(
            labelText: '${AppStrings.circleName} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: circles
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name,
                        style: const TextStyle(fontFamily: 'Tajawal')),
                  ))
              .toList(),
          onChanged: _selectedSchoolId == null
              ? null
              : (val) => setState(() => _selectedCircleId = val),
          validator: (val) => val == null ? AppStrings.fieldRequired : null,
          disabledHint: const Text('اختاري الدار أولاً',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
        ),
        if (_selectedSchoolId != null && circles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'لا توجد حلقات مضافة لهذه الدار بعد، تواصلي مع المشرفة العامة',
              style: TextStyle(
                  fontFamily: 'Tajawal', fontSize: 11, color: Colors.orange.shade700),
            ),
          ),
      ],
    );
  }

  Widget _buildAutoFilledDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedMonth,
      decoration: InputDecoration(
        labelText: '${AppStrings.month} *',
        filled: true,
        fillColor: AppTheme.lightGreen.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.4)),
        ),
      ),
      items: _hijriMonths
          .map((m) => DropdownMenuItem(value: m, child: Text(m,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14))))
          .toList(),
      onChanged: (val) => setState(() => _selectedMonth = val),
      validator: (val) => val == null ? AppStrings.fieldRequired : null,
    );
  }

  Widget _buildAutoFilledYearField() {
    final controller = TextEditingController(text: _selectedYear);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      onChanged: (val) => _selectedYear = val,
      style: const TextStyle(fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: '${AppStrings.year} *',
        filled: true,
        fillColor: AppTheme.lightGreen.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.4)),
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return AppStrings.fieldRequired;
        final year = int.tryParse(val);
        if (year == null || year < 1400 || year > 1500) {
          return AppStrings.invalidYear;
        }
        return null;
      },
    );
  }
}

class _ReadOnlyInfoCard extends ConsumerWidget {
  final dynamic user;

  const _ReadOnlyInfoCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mosques = ref.watch(activeMosquesProvider);
    final mosqueName = mosques
            .where((m) => m.id == user.mosqueId)
            .map((m) => m.name)
            .firstOrNull ??
        'غير محدد';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppTheme.primaryGreen,
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mosqueName,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppTheme.primaryGreen.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded,
              size: 15, color: AppTheme.primaryGreen.withOpacity(0.5)),
        ],
      ),
    );
  }
}