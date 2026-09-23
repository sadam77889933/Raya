import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../../../core/services/pdf_share_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/teachers_provider.dart';
import '../../../mosques/domain/entities/mosque.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../report_form/presentation/providers/all_reports_provider.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../data/statistical_report_aggregator.dart';
import '../../data/statistical_report_pdf_generator.dart';
import '../../domain/entities/statistical_report_result.dart';
import '../../domain/performance_rating.dart';
import '../widgets/follow_up_card.dart';
import '../widgets/kpi_card.dart';
import '../widgets/performance_indicator_bar.dart';
import '../widgets/rating_chip.dart';
import '../widgets/report_section_title.dart';
import '../widgets/student_summary_table.dart';

/// تقرير إحصائي لأداء حلقة واحدة عبر فترة هجرية مختارة — مُجمَّع من
/// التقارير الشهرية الموجودة أصلاً (وليس عرضاً متتابعاً لها). مخصَّص
/// للمشرفة (العامة أو مشرفة المسجد)، بنفس أسلوب فلاتر AttendanceReportScreen
/// الموجود مسبقاً في المشروع، مع فارق جوهري واحد: اختيار الحلقة هنا
/// **إلزامي** (وليس اختيارياً) لأن التقرير بطبيعته عن أداء حلقة واحدة
/// بعينها، وليس قائمة مسطّحة عبر عدة حلقات.
class StatisticalReportScreen extends ConsumerStatefulWidget {
  const StatisticalReportScreen({super.key});

  @override
  ConsumerState<StatisticalReportScreen> createState() =>
      _StatisticalReportScreenState();
}

class _StatisticalReportScreenState
    extends ConsumerState<StatisticalReportScreen> {
  late String _fromMonth;
  late String _fromYear;
  late String _toMonth;
  late String _toYear;

  String? _mosqueFilter;
  String? _schoolFilter;
  String? _circleFilter;
  String? _teacherFilter;

  @override
  void initState() {
    super.initState();
    final today = HijriCalendar.now();
    final currentMonth = QuranConstants.hijriMonths[today.hMonth - 1];
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

    final mosques = ref.watch(activeMosquesProvider);

    // تحسين أداء: حساب فلاتر المسجد/الدار/الحلقة لا يعتمد إطلاقاً على
    // بيانات التقارير نفسها (يعتمد فقط على مزوّدات المساجد/الدور/الحلقات)،
    // لذا يُحسَب أولاً هنا، قبل أي محاولة لجلب أي تقرير. بهذا لا نُحمّل أي
    // تقرير إطلاقاً طالما لم تُختَر حلقة بعد (كانت الشاشة سابقاً تُحمّل كل
    // تقارير كل الحلقات فقط لعرض رسالة "اختاري الحلقة").
    final effectiveMosqueFilter =
        isMosqueSupervisor ? user.mosqueId : _mosqueFilter;

    List<School> visibleSchools = const [];
    if (isMosqueSupervisor) {
      if (user.mosqueId != null) {
        visibleSchools =
            ref.watch(activeSchoolsByMosqueProvider(user.mosqueId!));
      }
    } else if (effectiveMosqueFilter != null) {
      visibleSchools =
          ref.watch(activeSchoolsByMosqueProvider(effectiveMosqueFilter));
    }

    if (_schoolFilter != null &&
        !visibleSchools.any((s) => s.id == _schoolFilter)) {
      _schoolFilter = null;
      _circleFilter = null;
    }

    // إن كانت هناك دار واحدة فقط، تُعرض كتسمية ثابتة بلا قائمة منسدلة
    // (_buildSingleValueLabel بالأسفل) فلا تُستدعى setState لتعيين
    // _schoolFilter إطلاقاً — نعتبرها مختارة تلقائياً هنا لتفادي ذلك.
    final selectedSchool = _schoolFilter != null
        ? _firstOrNull(visibleSchools.where((s) => s.id == _schoolFilter))
        : (visibleSchools.length == 1 ? visibleSchools.first : null);

    final schoolsForCircles =
        selectedSchool != null ? [selectedSchool] : visibleSchools;
    final visibleCircles = <TeachingCircle>[];
    for (final school in schoolsForCircles) {
      visibleCircles.addAll(
          ref.watch(activeTeachingCirclesBySchoolProvider(school.id)));
    }

    if (_circleFilter != null &&
        !visibleCircles.any((c) => c.id == _circleFilter)) {
      _circleFilter = null;
    }

    // نفس الملاحظة أعلاه: حلقة واحدة فقط تُعرض كتسمية ثابتة، فتُعتبر
    // مختارة تلقائياً هنا بدل انتظار اختيار لن يحدث إطلاقاً.
    final selectedCircle = _circleFilter != null
        ? _firstOrNull(visibleCircles.where((c) => c.id == _circleFilter))
        : (visibleCircles.length == 1 ? visibleCircles.first : null);

    final schoolNameFilter = selectedSchool?.name;
    final circleNameFilter = selectedCircle?.name;

    final periodLabel = _fromMonth == _toMonth && _fromYear == _toYear
        ? '$_fromMonth $_fromYear هـ'
        : 'من $_fromMonth $_fromYear هـ إلى $_toMonth $_toYear هـ';

    final mosqueName = effectiveMosqueFilter != null
        ? _firstOrNull(
            mosques.where((m) => m.id == effectiveMosqueFilter),
          )?.name
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير إحصائي لأداء الحلقة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilterCard(
            isGlobalSupervisor: isGlobalSupervisor,
            mosques: mosques,
            visibleSchools: visibleSchools,
            visibleCircles: visibleCircles,
            effectiveMosqueFilter: effectiveMosqueFilter,
          ),
          const SizedBox(height: 16),
          if (selectedCircle == null)
            _EmptyState(
              message: visibleCircles.isEmpty
                  ? 'اختاري المسجد ثم الدار لتظهر قائمة الحلقات'
                  : 'اختاري الحلقة لعرض تقريرها الإحصائي',
            )
          else
            _StatisticalReportData(
              circleId: selectedCircle.id,
              circleName: selectedCircle.name,
              fromMonth: _fromMonth,
              fromYear: _fromYear,
              toMonth: _toMonth,
              toYear: _toYear,
              mosqueIdFilter: effectiveMosqueFilter,
              schoolNameFilter: schoolNameFilter,
              circleNameFilter: circleNameFilter,
              teacherNameFilter: _teacherFilter,
              periodLabel: periodLabel,
              mosqueName: mosqueName,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterCard({
    required bool isGlobalSupervisor,
    required List<Mosque> mosques,
    required List<School> visibleSchools,
    required List<TeachingCircle> visibleCircles,
    required String? effectiveMosqueFilter,
  }) {
    return Container(
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
          _buildMonthYearRow('من', _fromMonth, _fromYear,
              (m) => setState(() => _fromMonth = m),
              (y) => setState(() => _fromYear = y)),
          const SizedBox(height: 8),
          _buildMonthYearRow('إلى', _toMonth, _toYear,
              (m) => setState(() => _toMonth = m),
              (y) => setState(() => _toYear = y)),
          const SizedBox(height: 16),
          Text('النطاق',
              style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          if (isGlobalSupervisor) ...[
            DropdownButtonFormField<String?>(
              // حارس أمان: نمرّر القيمة فقط إن كانت موجودة فعلاً ضمن
              // القائمة الحالية. بدون هذا، أي عدم تزامن مؤقت بين
              // _mosqueFilter والقائمة (كما حدث مع الدار والحلقة أدناه —
              // خاصة عند وصول دفق Firestore على مرحلتين: نسخة محلية مخزَّنة
              // ثم نسخة كاملة من السيرفر) يُسبّب Failed assertion من
              // DropdownButtonFormField نفسه ("There should be exactly one
              // item with [DropdownButton]'s value").
              value: mosques.any((m) => m.id == _mosqueFilter) ? _mosqueFilter : null,
              decoration: _filterDecoration(Icons.mosque_rounded, 'اختاري المسجد'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('اختاري المسجد')),
                ...mosques.map((m) => DropdownMenuItem<String?>(
                    value: m.id, child: Text(m.name))),
              ],
              onChanged: (val) => setState(() {
                _mosqueFilter = val;
                _schoolFilter = null;
                _circleFilter = null;
                _teacherFilter = null;
              }),
            ),
            const SizedBox(height: 8),
          ],
          if (visibleSchools.length == 1)
            _buildSingleValueLabel(
                Icons.apartment_rounded, 'الدار: ${visibleSchools.first.name}')
          else
            DropdownButtonFormField<String?>(
              // حارس أمان مطابق لقائمة المسجد أعلاه — راجع التعليق هناك.
              value: visibleSchools.any((s) => s.id == _schoolFilter)
                  ? _schoolFilter
                  : null,
              decoration:
                  _filterDecoration(Icons.apartment_rounded, 'اختاري الدار'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('اختاري الدار')),
                ...visibleSchools.map((s) =>
                    DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
              ],
              onChanged: visibleSchools.isEmpty
                  ? null
                  : (val) => setState(() {
                        _schoolFilter = val;
                        _circleFilter = null;
                        _teacherFilter = null;
                      }),
            ),
          const SizedBox(height: 8),
          if (visibleCircles.length == 1)
            _buildSingleValueLabel(
                Icons.groups_rounded, 'الحلقة: ${visibleCircles.first.name}')
          else
            DropdownButtonFormField<String?>(
              // حارس أمان مطابق لقائمة المسجد أعلاه — راجع التعليق هناك.
              value: visibleCircles.any((c) => c.id == _circleFilter)
                  ? _circleFilter
                  : null,
              decoration:
                  _filterDecoration(Icons.groups_rounded, 'اختاري الحلقة'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('اختاري الحلقة')),
                ...visibleCircles.map((c) =>
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
              ],
              onChanged: visibleCircles.isEmpty
                  ? null
                  : (val) => setState(() => _circleFilter = val),
            ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final teachersAsync = effectiveMosqueFilter != null
                  ? ref.watch(teachersByMosqueProvider(effectiveMosqueFilter))
                  : ref.watch(teachersStreamProvider);
              return teachersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (teachers) {
                  return DropdownButtonFormField<String?>(
                    // حارس أمان مطابق لبقية القوائم — كان هذا الحقل تحديداً
                    // بلا حارس إطلاقاً، وقيمته اسم المعلمة (نص) لا مُعرِّف
                    // (id)، وهذا هو أرجح مصدر الانهيار الفعلي الذي استمرّ
                    // ظاهراً حتى بعد إصلاح المسجد/الدار/الحلقة: عند تبديل
                    // الدار، قائمة `teachers` (وهي مرتبطة بالمسجد لا بالدار
                    // ولا بالحلقة) قد تتغيّر مؤقتاً (تحميل من جديد ثم بيانات
                    // كاملة)، فتُصبح `_teacherFilter` المحفوظة غير مطابقة
                    // لأي عنصر — أو لعنصرين متطابقين بالاسم لمعلمتين مختلفتين.
                    value: teachers.any((t) => t.name == _teacherFilter)
                        ? _teacherFilter
                        : null,
                    decoration: _filterDecoration(
                        Icons.person_outline_rounded, 'كل معلمات الحلقة'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('كل معلمات الحلقة')),
                      ...teachers.map((t) => DropdownMenuItem<String?>(
                          value: t.name, child: Text(t.name))),
                    ],
                    onChanged: (val) => setState(() => _teacherFilter = val),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

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
            child: Text(text,
                style: TextStyle(
                    fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700)),
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
            items: QuranConstants.hijriMonths
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
}

/// بديل بسيط عن Iterable.firstOrNull (من package:collection، غير مضاف
/// كاعتماد صريح في المشروع) — يتفادى إضافة اعتماد جديد لغرض واحد صغير.
T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

/// يجلب تقارير الحلقة المختارة فقط ضمن الفترة المطلوبة (مُصفّاة من جهة
/// السيرفر عبر [reportsByCircleAndPeriodProvider])، ثم يُجمّعها بنفس
/// [StatisticalReportAggregator] المستخدم سابقاً — فقط مصدر البيانات تغيّر
/// (حلقة واحدة ضمن فترة، بدل كل تقارير كل الحلقات)، لا منطق التجميع أو
/// التصفية بالمسجد/الدار/المعلمة، الذي يبقى كما هو تماماً فوق النتيجة
/// المُصغَّرة الآن.
class _StatisticalReportData extends ConsumerWidget {
  final String circleId;
  final String circleName;
  final String fromMonth;
  final String fromYear;
  final String toMonth;
  final String toYear;
  final String? mosqueIdFilter;
  final String? schoolNameFilter;
  final String? circleNameFilter;
  final String? teacherNameFilter;
  final String periodLabel;
  final String? mosqueName;

  const _StatisticalReportData({
    super.key,
    required this.circleId,
    required this.circleName,
    required this.fromMonth,
    required this.fromYear,
    required this.toMonth,
    required this.toYear,
    this.mosqueIdFilter,
    this.schoolNameFilter,
    this.circleNameFilter,
    this.teacherNameFilter,
    required this.periodLabel,
    this.mosqueName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromKey = QuranConstants.hijriPeriodKey(fromMonth, fromYear);
    final toKey = QuranConstants.hijriPeriodKey(toMonth, toYear);

    final reportsAsync = ref.watch(
      reportsByCircleAndPeriodProvider((circleId, fromKey, toKey)),
    );

    return reportsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Center(child: Text('حدث خطأ: $err')),
      data: (allReports) {
        final result = StatisticalReportAggregator.aggregate(
          allReports: allReports,
          fromMonth: fromMonth,
          fromYear: fromYear,
          toMonth: toMonth,
          toYear: toYear,
          mosqueIdFilter: mosqueIdFilter,
          schoolNameFilter: schoolNameFilter,
          circleNameFilter: circleNameFilter,
          teacherNameFilter: teacherNameFilter,
        );

        if (result.reportsCount == 0) {
          return const _EmptyState(
            message: 'لا توجد تقارير شهرية لهذه الحلقة ضمن الفترة المختارة',
          );
        }

        return _ReportBody(
          result: result,
          circleId: circleId,
          circleName: circleName,
          periodLabel: periodLabel,
          mosqueName: mosqueName,
          schoolName: schoolNameFilter,
          teacherName: teacherNameFilter,
        );
      },
    );
  }
}

/// جسم التقرير الكامل بعد اختيار حلقة فعلية: الملخص التنفيذي، مؤشرات
/// الأداء، الأداء العام، طالبات بحاجة إلى متابعة، والجدول المُجمَّع.
class _ReportBody extends ConsumerWidget {
  final StatisticalReportResult result;
  final String circleId;
  final String circleName;
  final String periodLabel;
  final String? mosqueName;
  final String? schoolName;
  final String? teacherName;

  const _ReportBody({
    required this.result,
    required this.circleId,
    required this.circleName,
    required this.periodLabel,
    this.mosqueName,
    this.schoolName,
    this.teacherName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider(circleId));
    final totalStudents = roster.students.length;
    final activeCount = roster.activeStudents.length;
    final inactiveCount = roster.inactiveStudents.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'نتائج حلقة: $circleName',
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700),
          ),
        ),
        const ReportSectionTitle(title: 'الملخص التنفيذي'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: [
            KpiCard(value: '$totalStudents', label: 'إجمالي الطالبات', isHero: true),
            KpiCard(
                value: result.avgAttendancePercent > 0
                    ? '${result.avgAttendancePercent.round()}%'
                    : '—',
                label: 'متوسط الحضور',
                isHero: true),
            KpiCard(value: '$activeCount', label: 'طالبات نشطات'),
            KpiCard(value: '$inactiveCount', label: 'طالبات غير نشطات'),
            KpiCard(
                value: result.avgAbsencePercent > 0
                    ? '${result.avgAbsencePercent.round()}%'
                    : '—',
                label: 'متوسط الغياب'),
            KpiCard(
                value: result.avgBehavior > 0
                    ? '${result.avgBehavior.toStringAsFixed(1)}/10'
                    : '—',
                label: 'متوسط السلوك'),
          ],
        ),
        const SizedBox(height: 18),
        const ReportSectionTitle(title: 'مؤشرات الأداء'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              PerformanceIndicatorBar(
                label: 'الحضور',
                percent: result.avgAttendancePercent,
                valueLabel: result.avgAttendancePercent > 0
                    ? '${result.avgAttendancePercent.round()}%'
                    : '—',
              ),
              PerformanceIndicatorBar(
                label: 'الغياب',
                percent: result.avgAbsencePercent,
                valueLabel: result.avgAbsencePercent > 0
                    ? '${result.avgAbsencePercent.round()}%'
                    : '—',
                isGold: true,
              ),
              PerformanceIndicatorBar(
                label: 'السلوك',
                percent: result.avgBehavior > 0 ? result.avgBehavior * 10 : 0.0,
                valueLabel:
                    result.avgBehavior > 0 ? result.avgBehavior.toStringAsFixed(1) : '—',
              ),
              PerformanceIndicatorBar(
                label: 'الحفظ',
                percent: PerformanceRating.scoreOf(result.overallMemorizationGrade) * 20.0,
                valueLabel: result.overallMemorizationGrade.isEmpty
                    ? '—'
                    : result.overallMemorizationGrade,
              ),
              PerformanceIndicatorBar(
                label: 'المراجعة',
                percent: PerformanceRating.scoreOf(result.overallRevisionGrade) * 20.0,
                valueLabel:
                    result.overallRevisionGrade.isEmpty ? '—' : result.overallRevisionGrade,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const ReportSectionTitle(title: 'الأداء العام للحلقة'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: [
            RatingChip(
                label: 'الحضور',
                grade: PerformanceRating.ratingFromPercent(result.avgAttendancePercent)),
            RatingChip(
                label: 'السلوك',
                grade: PerformanceRating.ratingFromPercent(result.avgBehavior * 10)),
            RatingChip(label: 'الحفظ', grade: result.overallMemorizationGrade),
            RatingChip(label: 'المراجعة', grade: result.overallRevisionGrade),
          ],
        ),
        const SizedBox(height: 18),
        ReportSectionTitle(
          title: 'طالبات بحاجة إلى متابعة',
          trailing: result.followUps.isNotEmpty
              ? Text('${result.followUps.length}',
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen))
              : null,
        ),
        if (result.followUps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('لا توجد طالبات بحاجة إلى متابعة حالياً — الأداء ضمن الحدود الطبيعية.',
                style: TextStyle(
                    fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500)),
          )
        else
          Column(
            children: result.followUps
                .map((f) => FollowUpCard(followUp: f))
                .toList(),
          ),
        const SizedBox(height: 18),
        const ReportSectionTitle(title: 'ملخّص أداء الطالبات خلال الفترة'),
        StudentSummaryTable(students: result.students),
        const SizedBox(height: 20),
        _ExportPdfButton(
          result: result,
          circleName: circleName,
          periodLabel: periodLabel,
          mosqueName: mosqueName,
          schoolName: schoolName,
          teacherName: teacherName,
          totalStudents: totalStudents,
          activeCount: activeCount,
          inactiveCount: inactiveCount,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// زر تصدير التقرير كـ PDF — يحمل حالته الخاصة (جاري التصدير أم لا)
/// بمعزل عن بقية الشاشة، بنفس نمط زر التصدير في AttendanceReportScreen
/// الموجود مسبقاً في المشروع.
class _ExportPdfButton extends StatefulWidget {
  final StatisticalReportResult result;
  final String circleName;
  final String periodLabel;
  final String? mosqueName;
  final String? schoolName;
  final String? teacherName;
  final int totalStudents;
  final int activeCount;
  final int inactiveCount;

  const _ExportPdfButton({
    required this.result,
    required this.circleName,
    required this.periodLabel,
    this.mosqueName,
    this.schoolName,
    this.teacherName,
    required this.totalStudents,
    required this.activeCount,
    required this.inactiveCount,
  });

  @override
  State<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<_ExportPdfButton> {
  bool _isExporting = false;

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await StatisticalReportPdfGenerator.generate(
        result: widget.result,
        circleName: widget.circleName,
        periodLabel: widget.periodLabel,
        mosqueName: widget.mosqueName,
        schoolName: widget.schoolName,
        teacherName: widget.teacherName,
        totalStudents: widget.totalStudents,
        activeCount: widget.activeCount,
        inactiveCount: widget.inactiveCount,
      );

      if (!mounted) return;
      final safeCircleName =
          widget.circleName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      await sharePdfBytes(
        bytes,
        fileName: 'تقرير_إحصائي_$safeCircleName.pdf',
        subject: 'تقرير إحصائي لأداء الحلقة',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تصدير PDF: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _export,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(_isExporting ? 'جاري التصدير...' : 'تصدير PDF'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
        ),
      ),
    );
  }
}
