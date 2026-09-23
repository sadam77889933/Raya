import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/pdf_share_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/domain/entities/mosque.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../data/roster_report_pdf_generator.dart';
import '../../domain/entities/roster_report_group.dart';

/// شاشة "قائمة أسماء الطالبات" — متاحة فقط لمشرفة المسجد (مقيّدة بمسجدها)
/// وللمشرف العام (بلا قيود). لا تظهر للمعلمة بأي شكل: لا رابط ولا مسار
/// يوصلها إليها، تماماً كبقية التقارير الإشرافية في هذا التطبيق.
///
/// الفلاتر (مسجد ← دار ← حلقة، مع خيار "الكل" في كل مستوى) بنفس النمط
/// المُتَّبع فعلاً في `AttendanceReportScreen` — إعادة استخدام حرفية،
/// وليس نمطاً جديداً، تلبيةً لطلب "الفلاتر معروفة مثل اللي قبل".
class RosterReportScreen extends ConsumerStatefulWidget {
  const RosterReportScreen({super.key});

  @override
  ConsumerState<RosterReportScreen> createState() =>
      _RosterReportScreenState();
}

class _RosterReportScreenState extends ConsumerState<RosterReportScreen> {
  String? _mosqueFilter; // null = كل المساجد (للمشرف العام فقط)
  String? _schoolFilter; // null = كل الدور
  String? _circleFilter; // null = كل الحلقات
  bool _showInactive = false;
  bool _isExporting = false;

  Future<void> _exportPdf(
    List<RosterReportGroup> groups, {
    required String? mosqueLabel,
    required String? schoolLabel,
    required String? circleLabel,
  }) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await RosterReportPdfGenerator.generate(
        groups: groups,
        showInactive: _showInactive,
        mosqueScopeLabel: mosqueLabel,
        schoolScopeLabel: schoolLabel,
        circleScopeLabel: circleLabel,
      );
      if (!mounted) return;
      await sharePdfBytes(
        bytes,
        fileName: 'قائمة_أسماء_الطالبات.pdf',
        subject: 'قائمة أسماء الطالبات',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تصدير الملف: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final isGlobalSupervisor = user.isSupervisor;
    // مشرفة المسجد مقفلة على مسجدها دائماً — لا "كل المساجد" لها إطلاقاً،
    // حتى لو تعذّر تحديد mosqueId لسبب ما (نفس مبدأ الأمان المتّبع في بقية
    // شاشات التقارير: تقييد افتراضي أضيق عند أي غموض، لا أوسع).
    final effectiveMosqueFilter =
        isGlobalSupervisor ? _mosqueFilter : user.mosqueId;

    final allMosques = ref.watch(activeMosquesProvider);

    final List<Mosque> mosquesInScope = effectiveMosqueFilter != null
        ? allMosques.where((m) => m.id == effectiveMosqueFilter).toList()
        : (isGlobalSupervisor ? allMosques : const <Mosque>[]);

    // ── الدور ضمن النطاق ──
    final List<School> visibleSchools = [];
    for (final mosque in mosquesInScope) {
      visibleSchools.addAll(ref.watch(activeSchoolsByMosqueProvider(mosque.id)));
    }
    if (_schoolFilter != null &&
        !visibleSchools.any((s) => s.id == _schoolFilter)) {
      _schoolFilter = null;
    }
    final selectedSchool = _schoolFilter != null
        ? visibleSchools.where((s) => s.id == _schoolFilter).firstOrNull
        : null;

    // ── الحلقات ضمن النطاق ──
    final schoolsForCircles =
        selectedSchool != null ? [selectedSchool] : visibleSchools;
    final List<TeachingCircle> visibleCircles = [];
    for (final school in schoolsForCircles) {
      visibleCircles
          .addAll(ref.watch(activeTeachingCirclesBySchoolProvider(school.id)));
    }
    if (_circleFilter != null &&
        !visibleCircles.any((c) => c.id == _circleFilter)) {
      _circleFilter = null;
    }
    final circlesForRoster = _circleFilter != null
        ? visibleCircles.where((c) => c.id == _circleFilter).toList()
        : visibleCircles;

    // ── تجميع طالبات كل حلقة ظاهرة ──
    final groups = <RosterReportGroup>[];
    for (final circle in circlesForRoster) {
      final school =
          visibleSchools.where((s) => s.id == circle.schoolId).firstOrNull;
      final mosque = school != null
          ? mosquesInScope.where((m) => m.id == school.mosqueId).firstOrNull
          : null;
      final rosterState = ref.watch(rosterProvider(circle.id));
      final students =
          _showInactive ? rosterState.students : rosterState.activeStudents;
      if (students.isEmpty) continue;
      groups.add(RosterReportGroup(
        mosqueName: mosque?.name ?? '',
        schoolName: school?.name ?? '',
        circleName: circle.name,
        students: students,
      ));
    }

    final totalCount = groups.fold<int>(0, (sum, g) => sum + g.students.length);

    final mosqueLabelForPdf = effectiveMosqueFilter != null
        ? mosquesInScope.firstOrNull?.name
        : null;
    final schoolLabelForPdf = selectedSchool?.name;
    final circleLabelForPdf = _circleFilter != null
        ? visibleCircles.where((c) => c.id == _circleFilter).map((c) => c.name).firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('قائمة أسماء الطالبات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الفلاتر',
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 10),
                  if (isGlobalSupervisor) ...[
                    DropdownButtonFormField<String?>(
                      value: _mosqueFilter,
                      decoration:
                          _filterDecoration(Icons.mosque_rounded, 'كل المساجد'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('كل المساجد')),
                        ...allMosques.map((m) => DropdownMenuItem<String?>(
                            value: m.id, child: Text(m.name))),
                      ],
                      onChanged: (val) => setState(() {
                        _mosqueFilter = val;
                        _schoolFilter = null;
                        _circleFilter = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                  ] else if (mosquesInScope.isNotEmpty) ...[
                    _buildSingleValueLabel(
                        Icons.mosque_rounded, 'المسجد: ${mosquesInScope.first.name}'),
                    const SizedBox(height: 8),
                  ],
                  if (visibleSchools.isNotEmpty) ...[
                    if (visibleSchools.length == 1)
                      _buildSingleValueLabel(Icons.apartment_rounded,
                          'الدار: ${visibleSchools.first.name}')
                    else
                      DropdownButtonFormField<String?>(
                        value: _schoolFilter,
                        decoration:
                            _filterDecoration(Icons.apartment_rounded, 'كل الدور'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('كل الدور')),
                          ...visibleSchools.map((s) => DropdownMenuItem<String?>(
                              value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (val) => setState(() {
                          _schoolFilter = val;
                          _circleFilter = null;
                        }),
                      ),
                    const SizedBox(height: 8),
                  ],
                  if (visibleCircles.isNotEmpty) ...[
                    if (visibleCircles.length == 1)
                      _buildSingleValueLabel(Icons.groups_rounded,
                          'الحلقة: ${visibleCircles.first.name}')
                    else
                      DropdownButtonFormField<String?>(
                        value: _circleFilter,
                        decoration:
                            _filterDecoration(Icons.groups_rounded, 'كل الحلقات'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('كل الحلقات')),
                          ...visibleCircles.map((c) => DropdownMenuItem<String?>(
                              value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (val) => setState(() => _circleFilter = val),
                      ),
                  ],
                  const SizedBox(height: 4),
                  Divider(color: Colors.grey.shade200),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('إظهار الطالبات غير النشطات',
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                color: Colors.grey.shade700)),
                      ),
                      Switch(
                        value: _showInactive,
                        onChanged: (val) => setState(() => _showInactive = val),
                        activeColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'عدد الطالبات: $totalCount',
              style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('لا توجد طالبات ضمن هذا النطاق',
                      style: TextStyle(
                          fontFamily: 'Tajawal', color: Colors.grey.shade400)),
                ),
              )
            else
              Column(
                children: [
                  for (final group in groups) ...[
                    if (groups.length > 1) ...[
                      Row(
                        children: [
                          Container(
                            width: 3.5,
                            height: 15,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${group.circleName} — ${group.schoolName}',
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${group.students.length}',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (var i = 0; i < group.students.length; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                group.students[i].name,
                                style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                            ),
                            if (!group.students[i].isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('غير نشطة',
                                    style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade500)),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportPdf(
                            groups,
                            mosqueLabel: mosqueLabelForPdf,
                            schoolLabel: schoolLabelForPdf,
                            circleLabel: circleLabelForPdf,
                          ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(_isExporting ? 'جارِ التصدير...' : 'تصدير PDF'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// تسمية للقيمة الوحيدة/المقفلة (مسجد مقفل، أو دار/حلقة وحيدة) بدل قائمة
  /// منسدلة لا فائدة من الاختيار منها — نفس الودجت المُستخدَم فعلاً في
  /// `AttendanceReportScreen` لهذا الغرض بالضبط.
  Widget _buildSingleValueLabel(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18),
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
