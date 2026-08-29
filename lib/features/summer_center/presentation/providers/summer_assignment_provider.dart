import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/summer_assignment.dart';
import 'summer_center_provider.dart';

/// كل إسنادات مركز واحد (لشاشة "توزيع المعلمات" عند المشرفة).
final summerAssignmentsByCenterProvider =
    StreamProvider.family.autoDispose<List<SummerAssignment>, String>((ref, centerId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchAssignmentsByCenter(centerId);
});

/// مفتاح مركّب (مركز + معلمة) لمزوّد family بمعامل واحد — مطلوب لأن
/// StreamProvider.family تأخذ نوع معامل واحد فقط.
class TeacherAssignmentsKey extends Equatable {
  final String centerId;
  final String teacherId;

  const TeacherAssignmentsKey(
      {required this.centerId, required this.teacherId});

  @override
  List<Object?> get props => [centerId, teacherId];
}

/// إسنادات معلمة واحدة داخل مركز واحد فقط (لشاشة "اختباراتي") — هذا هو
/// الاستعلام الوحيد الذي تحتاجه شاشة المعلمة لمعرفة مستوياتها ومودها.
final summerAssignmentsByTeacherProvider = StreamProvider.family
    .autoDispose<List<SummerAssignment>, TeacherAssignmentsKey>((ref, key) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref
      .watch(summerCenterRepositoryProvider)
      .watchAssignmentsByTeacher(key.centerId, key.teacherId);
});
