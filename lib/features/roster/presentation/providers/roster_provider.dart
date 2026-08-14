import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/roster_repository_impl.dart';
import '../../domain/entities/roster_student.dart';
import '../../domain/repositories/roster_repository.dart';

final rosterRepositoryProvider = Provider<RosterRepository>(
  (ref) => RosterRepositoryImpl(),
);

/// حالة شاشة سجل الحلقة
class RosterState {
  final List<RosterStudent> students;
  final String searchQuery;
  final bool isLoading;

  const RosterState({
    this.students = const [],
    this.searchQuery = '',
    this.isLoading = true,
  });

  /// الطالبات بعد تطبيق البحث
  List<RosterStudent> get filtered {
    if (searchQuery.trim().isEmpty) return students;
    return students
        .where((s) => s.name.contains(searchQuery.trim()))
        .toList();
  }

  List<RosterStudent> get activeStudents =>
      filtered.where((s) => s.isActive).toList();

  List<RosterStudent> get inactiveStudents =>
      filtered.where((s) => !s.isActive).toList();

  RosterState copyWith({
    List<RosterStudent>? students,
    String? searchQuery,
    bool? isLoading,
  }) {
    return RosterState(
      students: students ?? this.students,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RosterNotifier extends StateNotifier<RosterState> {
  final RosterRepository _repo;
  final _uuid = const Uuid();

  RosterNotifier(this._repo) : super(const RosterState()) {
    _load();
  }

  Future<void> _load() async {
    final students = await _repo.getAll();
    // ترتيب أبجدي لسهولة القراءة
    students.sort((a, b) => a.name.compareTo(b.name));
    state = state.copyWith(students: students, isLoading: false);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addStudent(String name) async {
    final student = RosterStudent(
      id: _uuid.v4(),
      name: name.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _repo.add(student);
    await _load();
  }

  Future<void> toggleActive(RosterStudent student) async {
    final updated = student.copyWith(isActive: !student.isActive);
    await _repo.update(updated);
    await _load();
  }

  Future<void> updateStudent(RosterStudent student) async {
    await _repo.update(student);
    await _load();
  }

  Future<void> deleteStudent(String id) async {
    await _repo.delete(id);
    await _load();
  }
}

final rosterProvider =
    StateNotifierProvider<RosterNotifier, RosterState>(
  (ref) => RosterNotifier(ref.read(rosterRepositoryProvider)),
);