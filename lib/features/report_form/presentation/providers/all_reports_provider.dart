import 'dart:async';

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

/// تقارير حلقة واحدة ضمن فترة هجرية محددة فقط — مُصفّاة من جهة السيرفر،
/// تُستخدم في التقرير الإحصائي بدل تحميل [allReportsStreamProvider] الكامل
/// (اختيار الحلقة هناك إلزامي دائماً، فيصلح `circleId` مفتاحاً للفلترة).
///
/// المفتاح Record ثلاثي: (circleId, fromPeriodKey, toPeriodKey).
/// `autoDispose` + `ref.keepAlive()` بمؤقّت 60 ثانية بنفس نمط بقية مزوّدات
/// الـfamily في المشروع — يُغلق الاستماع بعد مغادرة الشاشة بفترة قصيرة،
/// بدل إبقائه حيّاً للأبد لكل حلقة/فترة جُرِّبت ولو مرة.
final reportsByCircleAndPeriodProvider = StreamProvider.family
    .autoDispose<List<ReportSummary>, (String, int, int)>((ref, args) {
  final (circleId, fromPeriodKey, toPeriodKey) = args;
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  final service = ref.watch(firestoreReportServiceProvider);
  return service
      .watchReportsByCircleAndPeriod(
        circleId: circleId,
        fromPeriodKey: fromPeriodKey,
        toPeriodKey: toPeriodKey,
      )
      .map((list) => list.map((data) => ReportSummary.fromFirestore(data)).toList());
});