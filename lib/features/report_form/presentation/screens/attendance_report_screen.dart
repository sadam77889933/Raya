import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../data/attendance_aggregator.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/entities/student_attendance_summary.dart';
import '../providers/all_reports_provider.dart';
import '../providers/my_reports_provider.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/teachers_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/attendance_pdf_generator.dart';

class AttendanceReportScreen extends ConsumerStatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  ConsumerState<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState
    extends ConsumerState<AttendanceReportScreen> {
  late String _fromMonth;
  late String _fromYear;
  late String _toMonth;
  late String _toYear;

  String _studentFilter = '';
  String? _mosqueFilter;
  String? _teacherFilter; // اسم المعلمة المختارة (null = الكل)
  String _circleFilter = '';
  bool _isExporting = false;

  Future<void> _exportPdf(
    List<StudentAttendanceSummary> summaries,
    List<dynamic> mosques,
  ) async {
    setState(() => _isExporting = true);
    try {
      final mosqueName = _mosqueFilter != null
          ? mosques
              .where((m) => m.id == _mosqueFilter)
              .map((m) => m.name as String)
              .firstOrNull
          : null;

      final periodLabel = _fromMonth == _toMonth && _fromYear == _toYear
          ? '$_fromMonth $_fromYear'
          : 'من $_fromMonth $_fromYear إلى $_toMonth $_toYear';

      final path = await AttendancePdfGenerator.generate(
        summaries: summaries,
        periodLabel: periodLabel,
        mosqueName: mosqueName,
        teacherName: _teacherFilter,
        circleName: _circleFilter.trim().isEmpty ? null : _circleFilter.trim(),
      );

      if (!mounted) return;
      await Share.shareXFiles([XFile(path)],
          subject: 'تقرير الحضور والغياب');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
  @override
  void initState() {
    super.initState();
    final today = HijriCalendar.now();
    final currentMonth = AttendanceAggregator.hijriMonths[today.hMonth - 1];
    _fromMonth = currentMonth;
    _fromYear = today.hYear.toString();
    _toMonth = currentMonth;
    _toYear = today.hYear.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final isGlobalSupervisor = user.isSupervisor;
    final isMosqueSupervisor = user.isMosqueSupervisor;
    final isTeacher = !isGlobalSupervisor && !isMosqueSupervisor;

    final AsyncValue<List<ReportSummary>> reportsAsync;
    if (isTeacher) {
      reportsAsync = ref.watch(myReportsStreamProvider);
    } else {
      reportsAsync = ref.watch(allReportsStreamProvider);
    }

    final mosques = ref.watch(activeMosquesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الحضور والغياب')),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('حدث خطأ: $err')),
        data: (allReports) {
          final effectiveMosqueFilter =
              isMosqueSupervisor ? user.mosqueId : _mosqueFilter;

          final summaries = AttendanceAggregator.aggregate(
            allReports: allReports,
            fromMonth: _fromMonth,
            fromYear: _fromYear,
            toMonth: _toMonth,
            toYear: _toYear,
            studentNameFilter:
                _studentFilter.trim().isEmpty ? null : _studentFilter.trim(),
            mosqueIdFilter: effectiveMosqueFilter,
            teacherNameFilter: _teacherFilter,
            circleNameFilter:
                _circleFilter.trim().isEmpty ? null : _circleFilter.trim(),
          );

          return SingleChildScrollView(
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
                      Text('الفترة الهجرية',
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 10),
                      _buildMonthYearRow(
                          'من',
                          _fromMonth,
                          _fromYear,
                          (m) => setState(() => _fromMonth = m),
                          (y) => setState(() => _fromYear = y)),
                      const SizedBox(height: 8),
                      _buildMonthYearRow(
                          'إلى',
                          _toMonth,
                          _toYear,
                          (m) => setState(() => _toMonth = m),
                          (y) => setState(() => _toYear = y)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!isTeacher)
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
                        Text('فلاتر إضافية (اختيارية)',
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 10),
                        if (isGlobalSupervisor) ...[
                          DropdownButtonFormField<String?>(
                            value: _mosqueFilter,
                            decoration: _filterDecoration(
                                Icons.mosque_rounded, 'كل المساجد'),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('كل المساجد')),
                              ...mosques.map((m) => DropdownMenuItem<String?>(
                                  value: m.id, child: Text(m.name))),
                            ],
                            onChanged: (val) =>
                                setState(() => _mosqueFilter = val),
                          ),
                          const SizedBox(height: 8),
                        ],
                     Consumer(
                          builder: (context, ref, _) {
                            final teachersAsync = _mosqueFilter != null
                                ? ref.watch(
                                    teachersByMosqueProvider(_mosqueFilter!))
                                : ref.watch(teachersStreamProvider);

                            return teachersAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (teachers) {
                                return DropdownButtonFormField<String?>(
                                  value: _teacherFilter,
                                  decoration: _filterDecoration(
                                      Icons.person_outline_rounded,
                                      'كل المعلمات'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('كل المعلمات')),
                                    ...teachers.map(
                                      (t) => DropdownMenuItem<String?>(
                                        value: t.name,
                                        child: Text(t.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _teacherFilter = val),
                                );
                              },
                            );
                          },
                        ), 
                        const SizedBox(height: 8),
                        TextField(
                          onChanged: (v) => setState(() => _circleFilter = v),
                          decoration: _filterDecoration(
                              Icons.groups_rounded, 'اسم الحلقة (اختياري)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          onChanged: (v) => setState(() => _studentFilter = v),
                          decoration: _filterDecoration(
                              Icons.search_rounded, 'اسم طالبة معيّنة'),
                        ),
                      ],
                    ),
                  )
                else
                  TextField(
                    onChanged: (v) => setState(() => _studentFilter = v),
                    decoration: _filterDecoration(
                        Icons.search_rounded, 'اسم طالبة معيّنة (اختياري)'),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${summaries.length} طالبة',
                  style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: Colors.grey.shade500),
                ),
               const SizedBox(height: 10),
                if (summaries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('الطالبة',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                        ),
                        Expanded(
                          child: Text('حضور',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                        ),
                        Expanded(
                          child: Text('غياب',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                summaries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('لا توجد بيانات لهذه الفترة',
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: Colors.grey.shade400)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: summaries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                          final s = summaries[index];
                          return _buildRow(s);
                        },
                      ), 
                if (summaries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting
                          ? null
                          : () => _exportPdf(summaries, mosques),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: Text(
                          _isExporting ? 'جاري التصدير...' : 'تصدير PDF'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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

  Widget _buildMonthYearRow(
    String label,
    String month,
    String year,
    void Function(String) onMonthChanged,
    void Function(String) onYearChanged,
  ) {
    return Row(
      children: [
        SizedBox(
            width: 30,
            child: Text(label,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11))),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: month,
            isDense: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: OutlineInputBorder(),
            ),
            items: AttendanceAggregator.hijriMonths
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) => onMonthChanged(v!),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: TextFormField(
            initialValue: year,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: onYearChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(StudentAttendanceSummary s) {
    Color absenceColor;
    if (s.totalAbsenceDays >= 10) {
      absenceColor = Colors.red;
    } else if (s.totalAbsenceDays >= 5) {
      absenceColor = Colors.orange;
    } else {
      absenceColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      color: s.totalAbsenceDays >= 10
          ? Colors.red.withOpacity(0.05)
          : (s.totalAbsenceDays >= 5
              ? Colors.orange.withOpacity(0.05)
              : null),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(s.studentName,
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text('${s.totalAttendanceDays}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text('${s.totalAbsenceDays}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: absenceColor)),
          ),
        ],
      ),
    );
  }
}