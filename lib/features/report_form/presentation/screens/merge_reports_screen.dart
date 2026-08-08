import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../report_form/presentation/providers/all_reports_provider.dart';
import '../../data/pdf_generator.dart';
import '../providers/pdf_merger_provider.dart';

class MergeReportsScreen extends ConsumerStatefulWidget {
  const MergeReportsScreen({super.key});

  @override
  ConsumerState<MergeReportsScreen> createState() =>
      _MergeReportsScreenState();
}

class _MergeReportsScreenState extends ConsumerState<MergeReportsScreen> {
  final Set<String> _selectedMosqueIds = {};
  bool _isProcessing = false;
  String _statusText = '';

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
      final mosques = ref.read(activeMosquesProvider);

      // لكل مسجد مختار، نُنشئ ملفاً مدمجاً مستقلاً
      final List<String> generatedFiles = [];

      for (final mosqueId in _selectedMosqueIds) {
        final mosqueReports =
            allReports.where((r) => r.mosqueId == mosqueId).toList();

        if (mosqueReports.isEmpty) continue;

        final mosqueName = mosques
                .where((m) => m.id == mosqueId)
                .map((m) => m.name)
                .firstOrNull ??
            'مسجد';

        setState(() => _statusText = 'جاري إنشاء تقارير $mosqueName...');

        // إنشاء PDF فردي لكل تقرير
        final individualPaths = <String>[];
        for (final report in mosqueReports) {
          final circleReport = report.toCircleReport();
          final updatedReport = circleReport.copyWith(
            circleInfo:
                circleReport.circleInfo.copyWith(mosqueName: mosqueName),
          );
          final path = await PdfGenerator.instance.generate(updatedReport);
          individualPaths.add(path);
        }

        setState(() => _statusText = 'جاري دمج تقارير $mosqueName...');

        // دمج كل تقارير هذا المسجد في ملف واحد
        final mergedPath =
            await ref.read(pdfMergerServiceProvider).mergePdfs(
                  individualPaths,
                  outputFileName: 'تقارير_$mosqueName.pdf',
                );

        generatedFiles.add(mergedPath);
      }

      if (generatedFiles.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusText = '';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد تقارير للمساجد المختارة')),
        );
        return;
      }

      setState(() => _statusText = 'جاري فتح المشاركة...');

      await Share.shareXFiles(
        generatedFiles.map((p) => XFile(p)).toList(),
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
    final mosques = ref.watch(activeMosquesProvider);
    final allReportsAsync = ref.watch(allReportsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصدير تقارير مُدمَجة'),
      ),
      body: allReportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('حدث خطأ: $err')),
        data: (allReports) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختاري المساجد — سيُنشأ ملف PDF مستقل مدمج لكل مسجد',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: mosques.length,
                    itemBuilder: (context, index) {
                      final mosque = mosques[index];
                      final reportsCount = allReports
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
                                ? 'لا توجد تقارير'
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