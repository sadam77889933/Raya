import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../pdf_export/data/pdf_generator.dart';
import '../../domain/entities/report_summary.dart';
import 'edit_report_screen.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final ReportSummary report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  ConsumerState<ReportDetailScreen> createState() =>
      _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _isSharing = false;
  late ReportSummary _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Future<void> _editReport() async {
    final updated = await Navigator.of(context).push<ReportSummary>(
      MaterialPageRoute(
        builder: (_) => EditReportScreen(report: _report),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _report = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات بنجاح')),
      );
    }
  }

  Future<void> _shareReport(String mosqueName) async {
    setState(() => _isSharing = true);
    try {
      final mosques = ref.read(mosquesStreamProvider).value ?? [];
      final mosque =
          mosques.where((m) => m.id == _report.mosqueId).firstOrNull;

      Uint8List? stampBytes;
      if (mosque?.stampBase64 != null && mosque!.stampBase64!.isNotEmpty) {
        try {
          stampBytes = base64Decode(mosque.stampBase64!);
        } catch (_) {
          // ختم تالف أو غير صالح: نتجاهله ونترك المكان فارغاً بدل تعطيل التقرير
        }
      }

      final circleReport = _report.toCircleReport();
      final updatedReport = circleReport.copyWith(
        circleInfo: circleReport.circleInfo.copyWith(mosqueName: mosqueName),
      );

      final path = await PdfGenerator.instance.generate(
        updatedReport,
        stampBytes: stampBytes,
        supervisorName: mosque?.supervisorName,
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'تقرير حلقة القرآن الكريم',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إنشاء الملف: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final mosquesAsync = ref.watch(mosquesStreamProvider);
    final mosques = mosquesAsync.value ?? [];
    final mosquesLoading = mosquesAsync.isLoading;
    final mosqueName = mosquesLoading
        ? 'جاري التحميل...'
        : (mosques
                .where((m) => m.id == report.mosqueId)
                .map((m) => m.name)
                .firstOrNull ??
            'غير محدد');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل التقرير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل التقرير',
            onPressed: _editReport,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSharing ? null : () => _shareReport(mosqueName),
        backgroundColor: const Color(0xFF25D366),
        icon: _isSharing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.share_rounded, color: Colors.white),
        label: Text(
          _isSharing ? 'جاري التحضير...' : 'مشاركة PDF',
          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.circleName,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(label: 'المسجد', value: mosqueName),
                      ),
                      Expanded(
                        child: _InfoTile(
                            label: 'المعلمة', value: report.teacherName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'الشهر',
                          value: '${report.month} ${report.year}',
                        ),
                      ),
                      Expanded(
                        child: _InfoTile(
                          label: 'عدد الطالبات',
                          value: '${report.studentsCount} طالبة',
                        ),
                      ),
                    ],
                  ),
                  if (report.companionCurriculums.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoTile(
                      label: 'المنهج المصاحب',
                      value: report.companionCurriculums.join(' + '),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'الطالبات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),

            ...report.students.map((s) => _StudentCard(student: s)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentCard({required this.student});

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'ممتاز':
        return Colors.green;
      case 'جيد جداً':
        return Colors.orange;
      case 'جيد':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? '';
    final grade = student['grade'] as String? ?? '';
    final startSurah = student['startSurah'] as String? ?? '';
    final endSurah = student['endSurah'] as String? ?? '';
    final reviewStartSurah = student['reviewStartSurah'] as String? ?? '';
    final reviewEndSurah = student['reviewEndSurah'] as String? ?? '';
    final absenceDays = student['absenceDays'] as int? ?? 0;
    final color = _gradeColor(grade);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (grade.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.book_rounded, size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                'حفظ: $startSurah ← $endSurah',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'مراجعة: $reviewStartSurah ← $reviewEndSurah',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· غياب: $absenceDays',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}