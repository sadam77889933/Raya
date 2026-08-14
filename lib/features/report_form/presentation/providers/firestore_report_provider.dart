import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/firestore_report_repository.dart';

final firestoreReportServiceProvider = Provider<FirestoreReportService>(
  (ref) => FirestoreReportService(),
);