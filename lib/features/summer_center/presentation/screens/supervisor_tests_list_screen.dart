import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/pdf_share_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../data/summer_tests_export_service.dart';
import '../../domain/entities/hijri_month_period.dart';
import '../../domain/entities/summer_assignment.dart';
import '../../domain/entities/summer_center.dart';
import '../../domain/entities/summer_test.dart';
import '../../domain/services/tests_selection.dart';
import '../providers/summer_assignment_provider.dart';
import '../providers/summer_level_provider.dart';
import '../providers/summer_subject_provider.dart';
import '../providers/summer_test_provider.dart';
import '../providers/summer_tests_export_provider.dart';
import '../widgets/export_progress_dialog.dart';
import '../widgets/month_period_selector.dart';
import '../widgets/tests_export_bar.dart';
import '../widgets/tests_select_all_header.dart';
import 'test_editor_screen.dart';

/// شاشة "اختبارات المعلمات" — مراجعة المشرفة لكل اختبارات مركز صيفي واحد
/// بفلاتر: الشهر الهجري (الشهر الحالي افتراضياً، والأشهر السابقة عبر زر
/// «عرض الأشهر السابقة»)، ثم اختيارياً مستوى/مادة/معلمة. لا استعلام بلا
/// نطاق مركز محدَّد (centerId مُلزَم دائماً في summerTestsFilteredProvider).
///
/// يمكن تحديد اختبارات (يدوياً أو «تحديد الكل» للظاهر فقط) وتصديرها في ملف
/// PDF واحد ومشاركته. أي تغيير في أي فلتر يُفرِّغ التحديد.
class SupervisorTestsListScreen extends ConsumerStatefulWidget {
  final SummerCenter center;
  const SupervisorTestsListScreen({super.key, required this.center});

  @override
  ConsumerState<SupervisorTestsListScreen> createState() => _SupervisorTestsListScreenState();
}

class _SupervisorTestsListScreenState extends ConsumerState<SupervisorTestsListScreen> {
  String? _levelFilter;
  String? _subjectFilter;
  String? _teacherFilter;
  late HijriMonthPeriod _period;
  TestsSelection _selection = const TestsSelection.empty();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    // الشهر الحالي عند كل فتح للشاشة، فيظهر الشهر الجديد تلقائياً.
    _period = HijriMonthPeriod.current();
  }

  /// أي تغيير في الفلاتر يُفرِّغ التحديد، فلا يبقى اختبار محدَّد غير ظاهر.
  void _changeFilter(VoidCallback change) {
    setState(() {
      change();
      _selection = _selection.clear();
    });
  }

  Future<void> _openPastMonths(HijriMonthPeriod current) async {
    final picked = await showPastMonthsSheet(context, current: current, selected: _period);
    if (!mounted || picked == null || picked == _period) return;
    _changeFilter(() => _period = picked);
  }

  Future<void> _exportSelected(List<SummerTestsExportItem> items) async {
    if (_exporting || items.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final service = ref.read(summerTestsExportServiceProvider);
    final mosque = ref.read(activeMosquesProvider).where((m) => m.id == widget.center.mosqueId).firstOrNull;
    final progress = ValueNotifier<SummerTestsExportProgress>(
      SummerTestsExportProgress(done: 0, total: items.length),
    );
    final cancelToken = ExportCancelToken();

    setState(() => _exporting = true);
    var dialogOpen = true;
    void closeDialog() {
      if (!dialogOpen) return;
      dialogOpen = false;
      navigator.pop();
    }

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportProgressDialog(progress: progress, onCancel: cancelToken.cancel),
    ));

    try {
      final result = await service.export(
        items: items,
        centerName: widget.center.name,
        mosqueName: mosque?.name ?? '',
        rightHeaderText: mosque?.rightHeaderText,
        leftHeaderText: mosque?.leftHeaderText,
        headerLogoBytes: decodeHeaderLogoBase64(mosque?.headerLogoBase64),
        onProgress: (p) => progress.value = p,
        cancelToken: cancelToken,
      );
      closeDialog();
      await sharePdfBytes(
        result.bytes,
        fileName: SummerTestsExportService.fileName(
          tests: [for (final item in items) item.test],
          periodLabel: _period.label,
        ),
      );
      final skipped = result.skippedWithoutQuestions.length;
      if (skipped > 0) {
        messenger.showSnackBar(SnackBar(
          content: Text(skipped == 1
              ? 'استُبعد اختبار واحد من الملف لأنه لا يحتوي أسئلة'
              : 'استُبعدت $skipped اختبارات من الملف لأنها لا تحتوي أسئلة'),
        ));
      }
    } on SummerTestsExportCancelled {
      closeDialog();
    } on SummerTestsExportNothingToExportException {
      closeDialog();
      messenger.showSnackBar(
        const SnackBar(content: Text('الاختبارات المحدَّدة لا تحتوي أسئلة، فلا يوجد ما يُصدَّر')),
      );
    } on SummerTestsExportTooManyException catch (e) {
      closeDialog();
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } catch (e) {
      closeDialog();
      messenger.showSnackBar(SnackBar(content: Text('تعذّر تصدير الملف: $e')));
    } finally {
      progress.dispose();
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supervisor = ref.watch(authProvider).user;
    final levels = ref.watch(summerLevelsByCenterProvider(widget.center.id)).value ?? const [];
    final subjects = ref.watch(summerSubjectsByCenterProvider(widget.center.id)).value ?? const [];
    final assignments = ref.watch(summerAssignmentsByCenterProvider(widget.center.id)).value ?? const <SummerAssignment>[];

    final teachersById = <String, String>{};
    for (final a in assignments) {
      teachersById[a.teacherId] = a.teacherName;
    }
    final levelById = {for (final l in levels) l.id: l};
    final subjectById = {for (final s in subjects) s.id: s};

    final currentPeriod = HijriMonthPeriod.current();
    final testsAsync = ref.watch(summerTestsFilteredProvider(SummerTestFilter(
      centerId: widget.center.id,
      levelId: _levelFilter,
      subjectId: _subjectFilter,
      teacherId: _teacherFilter,
      period: _period,
    )));

    // «الظاهر» = ما تعرضه القائمة الآن؛ يُقاطَع معه كل تحديد وكل تصدير.
    final visibleTests = testsAsync.value ?? const <SummerTest>[];
    final visibleIds = [for (final t in visibleTests) t.id];
    final selectedIds = _selection.visibleSelected(visibleIds).toSet();
    final hasOtherFilters = _levelFilter != null || _subjectFilter != null || _teacherFilter != null;

    return Scaffold(
      appBar: AppBar(title: const Text('اختبارات المعلمات')),
      bottomNavigationBar: selectedIds.isEmpty
          ? null
          : TestsExportBar(
              selectedCount: selectedIds.length,
              maxCount: SummerTestsExportService.maxTestsPerExport,
              isExporting: _exporting,
              onExport: () => _exportSelected([
                for (final t in visibleTests)
                  if (selectedIds.contains(t.id))
                    SummerTestsExportItem(
                      test: t,
                      levelName: levelById[t.levelId]?.name ?? '',
                      subjectName: subjectById[t.subjectId]?.name ?? '',
                    ),
              ]),
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECECEC), width: 1.4),
              ),
              child: Column(
                children: [
                  MonthPeriodSelector(
                    selected: _period,
                    current: currentPeriod,
                    onChanged: (period) => _changeFilter(() => _period = period),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _levelFilter,
                          decoration: const InputDecoration(labelText: 'المستوى', isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('كل المستويات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                            for (final l in levels)
                              DropdownMenuItem(value: l.id, child: Text(l.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                          ],
                          onChanged: (value) => _changeFilter(() => _levelFilter = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _subjectFilter,
                          decoration: const InputDecoration(labelText: 'المادة', isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('كل المواد', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                            for (final s in subjects)
                              DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                          ],
                          onChanged: (value) => _changeFilter(() => _subjectFilter = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _teacherFilter,
                    decoration: const InputDecoration(labelText: 'المعلمة', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل المعلمات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                      for (final entry in teachersById.entries)
                        DropdownMenuItem(value: entry.key, child: Text(entry.value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5))),
                    ],
                    onChanged: (value) => _changeFilter(() => _teacherFilter = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: testsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('تعذّر التحميل', style: TextStyle(fontFamily: 'Tajawal'))),
                data: (tests) {
                  if (tests.isEmpty) {
                    return _NoTestsState(
                      periodLabel: _period.label,
                      hasOtherFilters: hasOtherFilters,
                      onShowPastMonths: () => _openPastMonths(currentPeriod),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TestsSelectAllHeader(
                        state: _selection.stateFor(visibleIds),
                        total: tests.length,
                        selectedCount: selectedIds.length,
                        onToggleAll: () => setState(() => _selection = _selection.toggleAll(visibleIds)),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: tests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final test = tests[i];
                            return _TestRow(
                              test: test,
                              levelName: levelById[test.levelId]?.name ?? '',
                              subjectName: subjectById[test.subjectId]?.name ?? '',
                              selected: _selection.contains(test.id),
                              onSelectionChanged: () => setState(() => _selection = _selection.toggle(test.id)),
                              onTap: () {
                                final level = levelById[test.levelId];
                                final subject = subjectById[test.subjectId];
                                if (level == null || subject == null || supervisor == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تعذّر فتح الاختبار', style: TextStyle(fontFamily: 'Tajawal'))),
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TestEditorScreen(
                                      testId: test.id,
                                      center: widget.center,
                                      level: level,
                                      subject: subject,
                                      currentUid: supervisor.uid,
                                      currentName: supervisor.name,
                                      isSupervisorView: true,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حالة «لا اختبارات في هذا الشهر» — مع طريق مباشر إلى الأشهر السابقة.
class _NoTestsState extends StatelessWidget {
  final String periodLabel;
  final bool hasOtherFilters;
  final VoidCallback onShowPastMonths;

  const _NoTestsState({
    required this.periodLabel,
    required this.hasOtherFilters,
    required this.onShowPastMonths,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            hasOtherFilters ? 'لا توجد اختبارات مطابقة في $periodLabel' : 'لا توجد اختبارات في $periodLabel',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onShowPastMonths,
            child: const Text('عرض الأشهر السابقة'),
          ),
        ],
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  final SummerTest test;
  final String levelName;
  final String subjectName;
  final bool selected;
  final VoidCallback onSelectionChanged;
  final VoidCallback onTap;

  const _TestRow({
    required this.test,
    required this.levelName,
    required this.subjectName,
    required this.selected,
    required this.onSelectionChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lightGreen.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppTheme.primaryGreen : const Color(0xFFECECEC), width: 1.4),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onSelectionChanged(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.title.isEmpty ? 'اختبار بلا عنوان' : test.title,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${test.teacherName} · $levelName · ${test.questionsCount} أسئلة',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Color(0xFFC7C7C7)),
          ],
        ),
      ),
    );
  }
}
