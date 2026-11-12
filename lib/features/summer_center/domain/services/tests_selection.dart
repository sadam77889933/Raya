import 'package:equatable/equatable.dart';

/// حالة خانة «تحديد الكل» نسبةً إلى النتائج الظاهرة حالياً فقط.
enum SelectAllState { none, partial, all }

/// تحديد اختبارات في قائمة (بمعرّفاتها) — منطق نقي بلا أي اعتماد على
/// الواجهة، وكل عملية تُعيد كائناً جديداً.
///
/// القاعدة الجوهرية: «الظاهر» هو ما تعرضه القائمة الآن بعد كل الفلاتر،
/// وكل ما يُحسب للتصدير أو للعدّاد يُقاطَع معه، فلا يُصدَّر أبداً اختبار
/// غير ظاهر حتى لو بقي معرّفه في التحديد.
class TestsSelection extends Equatable {
  final Set<String> _ids;

  const TestsSelection.empty() : _ids = const <String>{};

  TestsSelection._(Set<String> ids) : _ids = Set.unmodifiable(ids);

  bool contains(String id) => _ids.contains(id);

  bool get isEmpty => _ids.isEmpty;

  /// تحديد/إلغاء تحديد اختبار واحد.
  TestsSelection toggle(String id) {
    final next = Set<String>.of(_ids);
    if (!next.add(id)) next.remove(id);
    return TestsSelection._(next);
  }

  /// يحدّد الظاهر فقط، ويستبدل أي تحديد سابق (فلا يبقى معرّف غير ظاهر).
  TestsSelection selectAll(Iterable<String> visibleIds) =>
      TestsSelection._(visibleIds.toSet());

  TestsSelection clear() => const TestsSelection.empty();

  /// يُبقي المعرّفات الظاهرة فقط (مثلاً بعد حذف اختبار من القائمة).
  TestsSelection retainVisible(Iterable<String> visibleIds) =>
      TestsSelection._(_ids.intersection(visibleIds.toSet()));

  /// المحدَّد من بين الظاهر فقط، بترتيب الظهور.
  List<String> visibleSelected(Iterable<String> visibleIds) =>
      [for (final id in visibleIds) if (_ids.contains(id)) id];

  SelectAllState stateFor(Iterable<String> visibleIds) {
    final visible = visibleIds.toList();
    if (visible.isEmpty) return SelectAllState.none;
    final selectedCount = visible.where(_ids.contains).length;
    if (selectedCount == 0) return SelectAllState.none;
    return selectedCount == visible.length
        ? SelectAllState.all
        : SelectAllState.partial;
  }

  /// سلوك خانة «تحديد الكل»: إن كان كل الظاهر محدداً يُلغى التحديد، وإلا
  /// يُحدَّد كل الظاهر.
  TestsSelection toggleAll(Iterable<String> visibleIds) {
    return stateFor(visibleIds) == SelectAllState.all
        ? clear()
        : selectAll(visibleIds);
  }

  @override
  List<Object?> get props => [_ids];
}
