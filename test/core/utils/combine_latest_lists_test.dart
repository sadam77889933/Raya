import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/core/utils/combine_latest_lists.dart';

/// يترك لحلقات الأحداث (microtasks والمؤقّتات الصفرية) أن تُسلَّم.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('combineLatestLists', () {
    test('بلا تدفقات: قائمة فارغة واحدة ثم يُغلَق', () async {
      final events = <List<int>>[];
      var done = false;
      combineLatestLists<int>(const []).listen(events.add, onDone: () => done = true);
      await _settle();

      expect(events, equals([<int>[]]));
      expect(done, isTrue);
    });

    test('بتدفق واحد: يمرّر قيمه كما هي', () async {
      final source = StreamController<List<int>>();
      final events = <List<int>>[];
      final sub = combineLatestLists<int>([source.stream]).listen(events.add);

      source.add([1, 2]);
      source.add(<int>[]);
      await _settle();
      expect(events, equals([[1, 2], <int>[]]));

      await sub.cancel();
      await source.close();
    });

    test('لا يُصدر شيئاً حتى يُصدر كل تدفق قيمته الأولى', () async {
      final a = StreamController<List<int>>();
      final b = StreamController<List<int>>();
      final events = <List<int>>[];
      final sub = combineLatestLists<int>([a.stream, b.stream]).listen(events.add);

      a.add([1]);
      await _settle();
      expect(events, isEmpty);

      b.add([2, 3]);
      await _settle();
      expect(events, equals([[1, 2, 3]]));

      await sub.cancel();
      await a.close();
      await b.close();
    });

    test('يُعيد الإصدار عند تحديث أيٍّ منها ويحفظ ترتيب التدفقات لا ترتيب الوصول', () async {
      final a = StreamController<List<int>>();
      final b = StreamController<List<int>>();
      final events = <List<int>>[];
      final sub = combineLatestLists<int>([a.stream, b.stream]).listen(events.add);

      b.add([20]);
      a.add([10]);
      await _settle();
      expect(events.last, equals([10, 20]));

      a.add([11, 12]);
      await _settle();
      expect(events.last, equals([11, 12, 20]));

      b.add(<int>[]);
      await _settle();
      expect(events.last, equals([11, 12]));
      expect(events, hasLength(3));

      await sub.cancel();
      await a.close();
      await b.close();
    });

    test('خطأ أي تدفق يُمرَّر ولا يوقف البقية', () async {
      final a = StreamController<List<int>>();
      final b = StreamController<List<int>>();
      final events = <List<int>>[];
      final errors = <Object>[];
      final sub = combineLatestLists<int>([a.stream, b.stream]).listen(events.add, onError: errors.add);

      a.add([1]);
      b.addError(StateError('انقطع الاتصال'));
      await _settle();
      expect(errors, hasLength(1));
      expect(events, isEmpty);

      b.add([2]);
      await _settle();
      expect(events, equals([[1, 2]]));

      await sub.cancel();
      await a.close();
      await b.close();
    });

    test('يُغلَق فقط بعد إغلاق كل المصادر', () async {
      final a = StreamController<List<int>>();
      final b = StreamController<List<int>>();
      var done = false;
      final sub = combineLatestLists<int>([a.stream, b.stream]).listen((_) {}, onDone: () => done = true);

      a.add([1]);
      b.add([2]);
      await a.close();
      await _settle();
      expect(done, isFalse);

      await b.close();
      await _settle();
      expect(done, isTrue);

      await sub.cancel();
    });

    test('إلغاء الاشتراك يُلغي اشتراكات كل المصادر', () async {
      var cancelled = 0;
      final a = StreamController<List<int>>(onCancel: () {
        cancelled++;
      });
      final b = StreamController<List<int>>(onCancel: () {
        cancelled++;
      });
      final sub = combineLatestLists<int>([a.stream, b.stream]).listen((_) {});

      a.add([1]);
      await _settle();
      await sub.cancel();

      expect(cancelled, equals(2));
    });

    test('لا يشترك في المصادر قبل أن يستمع أحد إلى الناتج', () async {
      var listened = 0;
      final a = StreamController<List<int>>(onListen: () {
        listened++;
      });
      final b = StreamController<List<int>>(onListen: () {
        listened++;
      });
      final combined = combineLatestLists<int>([a.stream, b.stream]);
      await _settle();
      expect(listened, equals(0));

      final sub = combined.listen((_) {});
      await _settle();
      expect(listened, equals(2));

      await sub.cancel();
      await a.close();
      await b.close();
    });

    test('ثلاثة تدفقات (سنوات متعددة) تُدمج بالترتيب', () async {
      final controllers = [for (var i = 0; i < 3; i++) StreamController<List<String>>()];
      final events = <List<String>>[];
      final sub = combineLatestLists<String>([for (final c in controllers) c.stream]).listen(events.add);

      controllers[2].add(['ج']);
      controllers[0].add(['أ']);
      controllers[1].add(['ب1', 'ب2']);
      await _settle();

      expect(events, equals([['أ', 'ب1', 'ب2', 'ج']]));

      await sub.cancel();
      for (final c in controllers) {
        await c.close();
      }
    });
  });
}
