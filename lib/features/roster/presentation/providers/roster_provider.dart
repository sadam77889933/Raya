import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/roster_repository_impl.dart';
import '../../domain/entities/roster_student.dart';
import '../../domain/repositories/roster_repository.dart';

final rosterRepositoryProvider = Provider<RosterRepository>(
  (ref) => RosterRepositoryImpl(),
);

/// حالة شاشة سجل الحلقة (مُقسّمة حسب الحلقة عبر circleId)
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

/// إدارة سجل حلقة واحدة (circleId) — تشترك في دفق Firestore الحيّ
/// وتبقي حالة البحث محلياً بنفس أسلوب الشاشة السابق تماماً.
class RosterNotifier extends StateNotifier<RosterState> {
  final RosterRepository _repo;
  final String circleId;
  StreamSubscription<List<RosterStudent>>? _subscription;

  RosterNotifier(this._repo, this.circleId) : super(const RosterState()) {
    _subscription = _repo.watchByCircle(circleId).listen((students) {
      state = state.copyWith(students: students, isLoading: false);
    });
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addStudent(String name) async {
    await _repo.add(name.trim(), circleId);
    // لا حاجة لإعادة تحميل يدوي: الدفق الحيّ يُحدّث الحالة تلقائياً
  }

  Future<void> toggleActive(RosterStudent student) async {
    await _repo.setActive(student.id, !student.isActive);
  }

  Future<void> updateStudent(RosterStudent student) async {
    await _repo.updateName(student.id, student.name);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// تحسين أداء: كان هذا المزوّد (`.family` بلا `autoDispose`) يُبقي دفق
/// Firestore الحيّ لكل حلقة جرى فتح سجلّها في الجلسة مفتوحاً للأبد، حتى بعد
/// إغلاق شاشة السجل. `autoDispose` + `ref.keepAlive()` بمؤقّت 60 ثانية
/// يُغلق الدفق فعلياً بعد مغادرة الشاشة (مع فترة سماح قصيرة تمنع إعادة
/// الجلب الفوري لو رجعت المستخدمة لنفس الحلقة بسرعة).
final rosterProvider =
    StateNotifierProvider.family.autoDispose<RosterNotifier, RosterState, String>(
  (ref, circleId) {
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 60), link.close);
    ref.onDispose(timer.cancel);
    return RosterNotifier(ref.read(rosterRepositoryProvider), circleId);
  },
);
