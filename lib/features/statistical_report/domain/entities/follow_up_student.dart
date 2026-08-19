import 'package:equatable/equatable.dart';

import 'student_period_summary.dart';

/// طالبة تستوفي أحد معايير "بحاجة إلى متابعة" خلال الفترة المختارة.
///
/// [reasons] قد تحتوي أكثر من سبب واحد في نفس الوقت (مثلاً حضور منخفض
/// وسلوك منخفض معاً) — تُعرض كلها للمشرفة بدل الاكتفاء بأول سبب فقط.
class FollowUpStudent extends Equatable {
  final StudentPeriodSummary summary;
  final List<String> reasons;

  const FollowUpStudent({
    required this.summary,
    required this.reasons,
  });

  String get studentName => summary.studentName;

  @override
  List<Object?> get props => [summary, reasons];
}
