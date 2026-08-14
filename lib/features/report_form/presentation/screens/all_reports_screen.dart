import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../domain/entities/report_summary.dart';
import '../providers/all_reports_provider.dart';
import 'report_detail_screen.dart';

class AllReportsScreen extends ConsumerStatefulWidget {
  final String? restrictToMosqueId;

  const AllReportsScreen({super.key, this.restrictToMosqueId});

  @override
  ConsumerState<AllReportsScreen> createState() => _AllReportsScreenState();
}

class _AllReportsScreenState extends ConsumerState<AllReportsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(allReportsStreamProvider);
    final mosques = ref.watch(activeMosquesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('جميع التقارير'),
        backgroundColor: Colors.grey.shade100,
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('حدث خطأ: $err',
              style: const TextStyle(fontFamily: 'Tajawal')),
        ),
        data: (allReports) {
          final reports = widget.restrictToMosqueId == null
              ? allReports
              : allReports
                  .where((r) => r.mosqueId == widget.restrictToMosqueId)
                  .toList();
          final mosqueCount =
              reports.map((r) => r.mosqueId).toSet().length;
          final totalStudents =
              reports.fold<int>(0, (sum, r) => sum + r.studentsCount);

          final filtered = _searchQuery.trim().isEmpty
              ? reports
              : reports.where((r) {
                  final q = _searchQuery.trim();
                  return r.teacherName.contains(q) ||
                      r.circleName.contains(q);
                }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── الإحصائيات ─────────────────────────────
                Row(
                  children: [
                    _StatCard(count: reports.length, label: 'تقرير'),
                    const SizedBox(width: 8),
                    _StatCard(count: mosqueCount, label: 'مساجد'),
                    const SizedBox(width: 8),
                    _StatCard(count: totalStudents, label: 'طالبة'),
                  ],
                ),
                const SizedBox(height: 14),

                // ─── البحث ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'ابحثي باسم المعلمة أو المسجد...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ─── القائمة ─────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            reports.isEmpty
                                ? 'لا توجد تقارير مرفوعة بعد'
                                : 'لا توجد نتائج',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.grey.shade400,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final report = filtered[index];
                            
                            return _ReportCard(
                              report: report,
                             
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailScreen(report: report),
                                ),
                              ),
                            );
                          },
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

class _StatCard extends StatelessWidget {
  final int count;
  final String label;

  const _StatCard({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final ReportSummary report;
  final VoidCallback onTap;
  const _ReportCard({
    required this.report,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mosques = ref.watch(activeMosquesProvider);
    final mosqueName = mosques
            .where((m) => m.id == report.mosqueId)
            .map((m) => m.name)
            .firstOrNull ??
        'غير محدد';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.circleName,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${report.month} ${report.year}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.mosque_rounded, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  mosqueName,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_rounded,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      report.teacherName,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.groups_rounded,
                        size: 12, color: AppTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${report.studentsCount} طالبة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}