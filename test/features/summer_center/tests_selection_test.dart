import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/summer_center/domain/services/tests_selection.dart';

void main() {
  const visible = ['a', 'b', 'c', 'd'];

  group('TestsSelection', () {
    test('تبدأ فارغة', () {
      const selection = TestsSelection.empty();
      expect(selection.isEmpty, isTrue);
      expect(selection.contains('a'), isFalse);
      expect(selection.stateFor(visible), equals(SelectAllState.none));
    });

    test('toggle يحدد ثم يلغي، ولا يغيّر الكائن الأصلي', () {
      const empty = TestsSelection.empty();
      final one = empty.toggle('b');
      expect(one.contains('b'), isTrue);
      expect(empty.contains('b'), isFalse);

      final none = one.toggle('b');
      expect(none.contains('b'), isFalse);
      expect(none.isEmpty, isTrue);
    });

    test('التحديد اليدوي لبعض الاختبارات فقط يعطي حالة partial', () {
      final selection = const TestsSelection.empty().toggle('a').toggle('c');
      expect(selection.stateFor(visible), equals(SelectAllState.partial));
      expect(selection.visibleSelected(visible), equals(['a', 'c']));
    });

    test('selectAll يحدد كل الظاهر', () {
      final selection = const TestsSelection.empty().selectAll(visible);
      expect(selection.stateFor(visible), equals(SelectAllState.all));
      expect(selection.visibleSelected(visible), equals(visible));
    });

    test('selectAll يستبدل أي تحديد سابق فلا يبقى معرّف غير ظاهر', () {
      final selection = const TestsSelection.empty().toggle('hidden').selectAll(['a', 'b']);
      expect(selection.contains('hidden'), isFalse);
      expect(selection.visibleSelected(['a', 'b', 'hidden']), equals(['a', 'b']));
    });

    test('visibleSelected يتجاهل المحدَّد غير الظاهر ويحفظ ترتيب الظهور', () {
      final selection = const TestsSelection.empty().toggle('d').toggle('a').toggle('gone');
      expect(selection.visibleSelected(visible), equals(['a', 'd']));
    });

    test('retainVisible يُبقي الظاهر فقط', () {
      final selection = const TestsSelection.empty().toggle('a').toggle('x');
      final retained = selection.retainVisible(visible);
      expect(retained.contains('a'), isTrue);
      expect(retained.contains('x'), isFalse);
    });

    test('stateFor مع قائمة ظاهرة فارغة = none حتى لو بقي تحديد قديم', () {
      final selection = const TestsSelection.empty().toggle('a');
      expect(selection.stateFor(const <String>[]), equals(SelectAllState.none));
    });

    test('stateFor يحسب نسبةً إلى الظاهر فقط', () {
      final selection = const TestsSelection.empty().toggle('a').toggle('b').toggle('gone');
      expect(selection.stateFor(['a', 'b']), equals(SelectAllState.all));
      expect(selection.stateFor(visible), equals(SelectAllState.partial));
    });

    test('toggleAll: none → all، partial → all، all → none', () {
      const empty = TestsSelection.empty();
      final fromNone = empty.toggleAll(visible);
      expect(fromNone.stateFor(visible), equals(SelectAllState.all));

      final partial = empty.toggle('a');
      expect(partial.toggleAll(visible).stateFor(visible), equals(SelectAllState.all));

      expect(fromNone.toggleAll(visible).stateFor(visible), equals(SelectAllState.none));
      expect(fromNone.toggleAll(visible).isEmpty, isTrue);
    });

    test('clear يُفرِّغ التحديد', () {
      final selection = const TestsSelection.empty().selectAll(visible).clear();
      expect(selection.isEmpty, isTrue);
      expect(selection.stateFor(visible), equals(SelectAllState.none));
    });

    test('التساوي بالمحتوى لا بالترتيب', () {
      final first = const TestsSelection.empty().toggle('a').toggle('b');
      final second = const TestsSelection.empty().toggle('b').toggle('a');
      expect(first, equals(second));
    });
  });
}
