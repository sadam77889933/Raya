import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/report_summary.dart';
import 'firestore_report_provider.dart';

/// كل التقارير المرفوعة (لاستخدام المشرفة)
final allReportsStreamProvider = StreamProvider<List<ReportSummary>>((ref) {
  final service = ref.watch(firestoreReportServiceProvider);
  return service.watchAllReports().map(
        (list) => list.map((data) => ReportSummary.fromFirestore(data)).toList(),
      );
});