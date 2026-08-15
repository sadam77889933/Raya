import '../entities/roster_student.dart';

/// عقد مجرّد لتخزين واسترجاع سجل الحلقة — مُقسّم حسب معرّف الحلقة (circleId)
///
/// النسخة الحالية: Firestore (نفس نمط المساجد/الدور/الحلقات)، مع دفق
/// حيّ (snapshots) يمنحنا مزامنة فورية بين الأجهزة وتخزيناً مؤقتاً
/// دون اتصال مجاناً من حزمة Firestore نفسها.
abstract class RosterRepository {
  Stream<List<RosterStudent>> watchByCircle(String circleId);
  Future<void> add(String name, String circleId);
  Future<void> updateName(String studentId, String name);
  Future<void> setActive(String studentId, bool isActive);
}
