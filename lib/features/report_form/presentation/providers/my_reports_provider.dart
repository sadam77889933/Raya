import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/report_summary.dart';
import 'firestore_report_provider.dart';

/// تقارير المعلمة الحالية فقط (وليس كل التقارير)
final myReportsStreamProvider = StreamProvider<List<ReportSummary>>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return const Stream.empty();

  final service = ref.watch(firestoreReportServiceProvider);
  return service.watchTeacherReports(user.uid).map(
        (list) => list.map((data) => ReportSummary.fromFirestore(data)).toList(),
      );
});