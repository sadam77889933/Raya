import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/roster_student.dart';
import '../domain/repositories/roster_repository.dart';

/// تنفيذ فعلي للسجل باستخدام SharedPreferences
/// يحفظ قائمة الطالبات كـ JSON في مفتاح واحد
class RosterRepositoryImpl implements RosterRepository {
  static const _key = 'roster_students_v1';

  @override
  Future<List<RosterStudent>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => RosterStudent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAll(List<RosterStudent> students) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(students.map((s) => s.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  @override
  Future<void> add(RosterStudent student) async {
    final all = await getAll();
    all.add(student);
    await _saveAll(all);
  }

  @override
  Future<void> update(RosterStudent student) async {
    final all = await getAll();
    final index = all.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      all[index] = student;
      await _saveAll(all);
    }
  }

  @override
  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((s) => s.id == id);
    await _saveAll(all);
  }
}