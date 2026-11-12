import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/summer_tests_export_service.dart';
import 'summer_center_provider.dart';

/// خدمة تصدير عدة اختبارات في ملف PDF واحد — تقرأ أسئلة كل اختبار عند
/// الطلب فقط (لا تحميل مسبق لأسئلة أي اختبار).
final summerTestsExportServiceProvider = Provider<SummerTestsExportService>(
  (ref) => SummerTestsExportService(
    loadQuestions: ref.watch(summerCenterRepositoryProvider).getQuestions,
  ),
);
