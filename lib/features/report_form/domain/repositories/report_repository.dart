import '../entities/circle_report.dart';

abstract class ReportRepository {
  Future<void> saveReport(CircleReport report);
  Future<List<CircleReport>> getAllReports();
  Future<CircleReport?> getReportById(String id);
  Future<void> deleteReport(String id);
}