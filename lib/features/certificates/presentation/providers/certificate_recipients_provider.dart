import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mosques/domain/entities/mosque.dart';
import '../../../mosques/domain/entities/school.dart';
import '../../../mosques/domain/entities/teaching_circle.dart';
import '../../../mosques/presentation/providers/mosque_provider.dart';
import '../../../mosques/presentation/providers/school_provider.dart';
import '../../../mosques/presentation/providers/teaching_circle_provider.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../../roster_report/domain/entities/roster_report_group.dart';

/// يجمع طالبات كل حلقات مسجد واحد، مُقسَّمة حسب الحلقة — بنفس منطق
/// التجميع المستخدَم فعلياً في RosterReportScreen حرفياً (مسجد ← دار ←
/// حلقة ← طالبات نشطات فقط، لأن الشهادات تُصدَر للطالبات النشطات حالياً).
///
/// إعادة استخدام `RosterReportGroup` نفسه بدل تعريف كيان مطابق جديد —
/// كلاهما "طالبات حلقة واحدة ضمن نطاق"، لا داعي لتكرار الشكل.
final certificateRecipientGroupsProvider =
    Provider.family.autoDispose<List<RosterReportGroup>, String>((ref, mosqueId) {
  final mosques = ref.watch(activeMosquesProvider);
  final Mosque? mosque =
      mosques.where((m) => m.id == mosqueId).firstOrNull;
  if (mosque == null) return const [];

  final List<School> schools =
      ref.watch(activeSchoolsByMosqueProvider(mosqueId));

  final groups = <RosterReportGroup>[];
  for (final school in schools) {
    final List<TeachingCircle> circles =
        ref.watch(activeTeachingCirclesBySchoolProvider(school.id));
    for (final circle in circles) {
      final rosterState = ref.watch(rosterProvider(circle.id));
      final students = rosterState.activeStudents;
      if (students.isEmpty) continue;
      groups.add(RosterReportGroup(
        mosqueName: mosque.name,
        schoolName: school.name,
        circleName: circle.name,
        students: students,
      ));
    }
  }
  return groups;
});
