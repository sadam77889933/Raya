import '../entities/roster_student.dart';

/// عقد مجرّد لتخزين واسترجاع سجل الحلقة
///
/// النسخة الحالية: SharedPreferences (محلي على الجهاز)
/// النسخة القادمة: Firebase — بدون تغيير أي كود يستخدم هذا العقد
abstract class RosterRepository {
  Future<List<RosterStudent>> getAll();
  Future<void> add(RosterStudent student);
  Future<void> update(RosterStudent student);
  Future<void> delete(String id);
}