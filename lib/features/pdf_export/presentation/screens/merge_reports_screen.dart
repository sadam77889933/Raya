import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../../../core/services/pdf_share_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../report_form/domain/entities/report_summary.dart';
import '../../../report_form/presentation/providers/all_reports_provider.dart';
import '../../data/pdf_generator.dart';
import '../providers/pdf_merger_provider.dart';

const List<String> _hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
  'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
  'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

const String _allPeriodsOption = 'كل الفترات';

class MergeReportsScreen extends ConsumerStatefulWidget {
  final String? restrictToMosqueId;

  const MergeReportsScreen({super.key, this.restrictToMosqueId});

  @override
  ConsumerState<MergeReportsScreen> createState() =>
      _MergeReportsScreenState();
}

class _MergeReportsScreenState extends ConsumerState<MergeReportsScreen> {
  final Set<String> _selectedMosqueIds = {};
  bool _isProcessing = false;
  String _statusText = '';

  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();
    final today = HijriCalendar.now();
    _selectedMonth = _hijriMonths[today.hMonth - 1];
    _selectedYear = today.hYear.toString();

    // إذا كانت الشاشة مقيَّدة بمسجد واحد، نحدّده تلقائياً ونمنع تغييره
    if (widget.restrictToMosqueId != null) {
      _selectedMosqueIds.add(widget.restrictToMosqueId!);
    }
  }

  List<ReportSummary> _filterByPeriod(List<ReportSummary> reports) {
    if (_selectedMonth == _allPeriodsOption) return reports;
    return reports
        .where((r) => r.month == _selectedMonth && r.year == _selectedYear)
        .toList();
  }

  Future<void> _mergeAndShare() async {
    if (_selectedMosqueIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري مسجداً واحداً على الأقل')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'جاري تجهيز التقارير...';
    });

    try {
      final allReports = ref.read(allReportsStreamProvider).value ?? [];
      final filteredReports = _filterByPeriod(allReports);
      final mosques = ref.read(activeMosquesProvider);
      final circles = ref.read(teachingCirclesStreamProvider).value ?? [];

      final List<PdfShareItem> generatedFiles = [];

      for (final mosqueId in _selectedMosqueIds) {
        final mosqueReports =
            filteredReports.where((r) => r.mosqueId == mosqueId).toList();

        if (mosqueReports.isEmpty) continue;

        final mosque = mosques.where((m) => m.id == mosqueId).firstOrNull;
        final mosqueName = mosque?.name ?? 'مسجد';

        Uint8List? stampBytes;
        if (mosque?.stampBase64 != null && mosque!.stampBase64!.isNotEmpty) {
          try {
            stampBytes = base64Decode(mosque.stampBase64!);
          } catch (_) {
            // ختم تالف أو غير صالح: نتجاهله ونترك المكان فارغاً بدل تعطيل التقرير
          }
        }

        Uint8List? headerLogoBytes;
        if (mosque?.headerLogoBase64 != null &&
            mosque!.headerLogoBase64!.isNotEmpty) {
          try {
            headerLogoBytes = base64Decode(mosque.headerLogoBase64!);
          } catch (_) {
            // شعار تالف أو غير صالح: نتجاهله ونترك مكانه فارغاً بدل تعطيل التقرير
          }
        }

        setState(() => _statusText = 'جاري إنشاء تقارير $mosqueName...');

        final individualPdfBytesList = <Uint8List>[];
        for (final report in mosqueReports) {
          final circleReport = report.toCircleReport();
          final updatedReport = circleReport.copyWith(
            circleInfo:
                circleReport.circleInfo.copyWith(mosqueName: mosqueName),
          );
          final circleTime = circles
              .where((c) => c.id == report.circleId)
              .map((c) => c.circleTime)
              .firstOrNull;

          final bytes = await PdfGenerator.instance.generate(
            updatedReport,
            stampBytes: stampBytes,
            supervisorName: mosque?.supervisorName,
            rightHeaderText: mosque?.rightHeaderText,
            leftHeaderText: mosque?.leftHeaderText,
            headerLogoBytes: headerLogoBytes,
            monthlyBannerText: mosque?.monthlyBannerText,
            circleTime: circleTime,
          );
          individualPdfBytesList.add(bytes);
        }

        setState(() => _statusText = 'جاري دمج تقارير $mosqueName...');

        final mergedBytes = await ref
            .read(pdfMergerServiceProvider)
            .mergePdfs(individualPdfBytesList);

        final mergedFileName = 'تقارير_$mosqueName.pdf';
        generatedFiles.add(
          PdfShareItem(bytes: mergedBytes, fileName: mergedFileName),
        );
      }

      if (generatedFiles.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusText = '';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لا توجد تقارير للمساجد والفترة المختارة')),
        );
        return;
      }

      setState(() => _statusText = 'جاري فتح المشاركة...');

      await sharePdfFiles(
        generatedFiles,
        subject: 'تقارير الحلقات المدمجة',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMosques = ref.watch(activeMosquesProvider);
    final mosques = widget.restrictToMosqueId == null
        ? allMosques
        : allMosques
            .where((m) => m.id == widget.restrictToMosqueId)
            .toList();
    final allReportsAsync = ref.watch(allReportsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصدير تقارير مُدمَجة'),
      ),
      body: allReportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('حدث خطأ: $err')),
        data: (allReports) {
          final filteredReports = _filterByPeriod(allReports);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حدّدي الفترة الزمنية',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: [
                          ..._hijriMonths.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style: const TextStyle(
                                        fontFamily: 'Tajawal', fontSize: 13)),
                              )),
                          const DropdownMenuItem(
                            value: _allPeriodsOption,
                            child: Text(_allPeriodsOption,
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedMonth = val!),
                      ),
                    ),
                    if (_selectedMonth != _allPeriodsOption) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: _selectedYear,
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _selectedYear = val,
                          style: const TextStyle(
                              fontFamily: 'Tajawal', fontSize: 13),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  'اختاري المساجد — سيُنشأ ملف PDF مستقل مدمج لكل مسجد',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: mosques.length,
                    itemBuilder: (context, index) {
                      final mosque = mosques[index];
                      final reportsCount = filteredReports
                          .where((r) => r.mosqueId == mosque.id)
                          .length;
                      final isSelected =
                          _selectedMosqueIds.contains(mosque.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? AppTheme.lightGreen : null,
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: reportsCount == 0
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedMosqueIds.add(mosque.id);
                                    } else {
                                      _selectedMosqueIds.remove(mosque.id);
                                    }
                                  });
                                },
                          title: Text(
                            mosque.name,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            reportsCount == 0
                                ? 'لا توجد تقارير لهذه الفترة'
                                : '$reportsCount تقرير',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: reportsCount == 0
                                  ? Colors.red.shade300
                                  : Colors.grey.shade500,
                            ),
                          ),
                          activeColor: AppTheme.primaryGreen,
                        ),
                      );
                    },
                  ),
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                              fontFamily: 'Tajawal', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _mergeAndShare,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  label: Text(
                    _selectedMosqueIds.isEmpty
                        ? 'اختاري مسجداً للتصدير'
                        : 'تصدير ${_selectedMosqueIds.length} ملف مدمج',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}