import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/roster_student.dart';
import 'roster_provider.dart';

/// حالة شاشة اختيار الطالبات لتقرير هذا الشهر
class SelectStudentsState {
  final String searchQuery;
  final Set<String> selectedIds;

  const SelectStudentsState({
    this.searchQuery = '',
    this.selectedIds = const {},
  });

  SelectStudentsState copyWith({
    String? searchQuery,
    Set<String>? selectedIds,
  }) {
    return SelectStudentsState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class SelectStudentsNotifier extends StateNotifier<SelectStudentsState> {
  SelectStudentsNotifier() : super(const SelectStudentsState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggle(String id) {
    final updated = {...state.selectedIds};
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedIds: updated);
  }

  void selectAll(List<RosterStudent> students) {
    state = state.copyWith(
      selectedIds: students.map((s) => s.id).toSet(),
    );
  }

  void clearAll() {
    state = state.copyWith(selectedIds: {});
  }

  void reset() {
    state = const SelectStudentsState();
  }
}

final selectStudentsProvider =
    StateNotifierProvider<SelectStudentsNotifier, SelectStudentsState>(
  (ref) => SelectStudentsNotifier(),
);