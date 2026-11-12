import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/summer_center/domain/entities/hijri_month_period.dart';
import 'package:quran_circle_report/features/summer_center/domain/entities/hijri_month_range.dart';

const _muharram1448 = HijriMonthPeriod(month: 'محرم', year: '1448');
const _safar1448 = HijriMonthPeriod(month: 'صفر', year: '1448');
const _jumada1_1448 = HijriMonthPeriod(month: 'جمادى الأولى', year: '1448');
const _jumada2_1448 = HijriMonthPeriod(month: 'جمادى الآخرة', year: '1448');
const _rajab1448 = HijriMonthPeriod(month: 'رجب', year: '1448');
const _dhulQidah1447 = HijriMonthPeriod(month: 'ذو القعدة', year: '1447');
const _dhulHijjah1447 = HijriMonthPeriod(month: 'ذو الحجة', year: '1447');

void main() {
  group('HijriMonthRange — الإنشاء', () {
    test('recent: الشهر السابق ثم الشهر الحالي', () {
      final range = HijriMonthRange.recent(current: _jumada2_1448);
      expect(range.from, equals(_jumada1_1448));
      expect(range.to, equals(_jumada2_1448));
      expect(range.isSingleMonth, isFalse);
    });

    test('recent يعبر حدود السنة (الحالي محرم ← السابق ذو الحجة)', () {
      final range = HijriMonthRange.recent(current: _muharram1448);
      expect(range.from, equals(_dhulHijjah1447));
      expect(range.to, equals(_muharram1448));
    });

    test('recent بلا معامل: النهاية الشهر الحالي والبداية الشهر الذي قبله', () {
      final range = HijriMonthRange.recent();
      final now = HijriMonthPeriod.current();
      expect(range.to, equals(now));
      expect(range.from, equals(now.previous()));
    });

    test('ordered يرتّب الطرفين أياً كان ترتيب الإدخال', () {
      expect(HijriMonthRange.ordered(_rajab1448, _safar1448), equals(const HijriMonthRange(from: _safar1448, to: _rajab1448)));
      expect(HijriMonthRange.ordered(_safar1448, _rajab1448), equals(const HijriMonthRange(from: _safar1448, to: _rajab1448)));
    });

    test('isSingleMonth عند تساوي الطرفين', () {
      expect(const HijriMonthRange(from: _rajab1448, to: _rajab1448).isSingleMonth, isTrue);
    });

    test('التساوي بالقيمة', () {
      expect(
        const HijriMonthRange(from: _safar1448, to: _rajab1448),
        equals(const HijriMonthRange(from: _safar1448, to: _rajab1448)),
      );
      expect(
        const HijriMonthRange(from: _safar1448, to: _rajab1448) == const HijriMonthRange(from: _safar1448, to: _jumada2_1448),
        isFalse,
      );
    });
  });

  group('HijriMonthRange — تغيير الطرفين يُبقي النطاق صحيحاً', () {
    const range = HijriMonthRange(from: _safar1448, to: _jumada2_1448);

    test('withFrom قبل النهاية: تبقى النهاية', () {
      expect(range.withFrom(_muharram1448), equals(const HijriMonthRange(from: _muharram1448, to: _jumada2_1448)));
    });

    test('withFrom بعد النهاية: تصير النهاية هي البداية نفسها', () {
      expect(range.withFrom(_rajab1448), equals(const HijriMonthRange(from: _rajab1448, to: _rajab1448)));
    });

    test('withFrom يساوي النهاية: شهر واحد', () {
      expect(range.withFrom(_jumada2_1448).isSingleMonth, isTrue);
    });

    test('withTo بعد البداية: تبقى البداية', () {
      expect(range.withTo(_rajab1448), equals(const HijriMonthRange(from: _safar1448, to: _rajab1448)));
    });

    test('withTo قبل البداية: تصير البداية هي النهاية نفسها', () {
      expect(range.withTo(_muharram1448), equals(const HijriMonthRange(from: _muharram1448, to: _muharram1448)));
    });

    test('withTo عبر حدود السنة', () {
      expect(range.withTo(_dhulHijjah1447), equals(const HijriMonthRange(from: _dhulHijjah1447, to: _dhulHijjah1447)));
    });

    test('النتيجة دائماً بداية ≤ نهاية لأي مزيج من الاختيارات', () {
      final all = [_dhulQidah1447, _dhulHijjah1447, _muharram1448, _safar1448, _jumada1_1448, _jumada2_1448, _rajab1448];
      for (final a in all) {
        for (final b in all) {
          final r = range.withFrom(a).withTo(b);
          expect(r.from.key <= r.to.key, isTrue, reason: '${a.label} / ${b.label}');
          final r2 = range.withTo(b).withFrom(a);
          expect(r2.from.key <= r2.to.key, isTrue, reason: '${b.label} / ${a.label}');
        }
      }
    });
  });

  group('HijriMonthRange — الأشهر والتجميع', () {
    test('periods لشهر واحد', () {
      expect(const HijriMonthRange(from: _rajab1448, to: _rajab1448).periods, equals([_rajab1448]));
    });

    test('periods لشهرين بالترتيب من الأقدم إلى الأحدث', () {
      expect(const HijriMonthRange(from: _jumada1_1448, to: _jumada2_1448).periods, equals([_jumada1_1448, _jumada2_1448]));
    });

    test('periods تعبر حدود السنة وتشمل الطرفين', () {
      final periods = const HijriMonthRange(from: _dhulQidah1447, to: _safar1448).periods;
      expect(periods, equals([_dhulQidah1447, _dhulHijjah1447, _muharram1448, _safar1448]));
    });

    test('periods: كل شهر يزيد بواحد بالضبط', () {
      final periods = const HijriMonthRange(
        from: HijriMonthPeriod(month: 'رجب', year: '1445'),
        to: _rajab1448,
      ).periods;
      expect(periods, hasLength(37));
      for (var i = 1; i < periods.length; i++) {
        expect(periods[i].key, equals(periods[i - 1].key + 1));
      }
    });

    test('monthsByYear تجمّع بالسنة بترتيب السنوات ثم الأشهر', () {
      final grouped = const HijriMonthRange(from: _dhulQidah1447, to: _safar1448).monthsByYear;
      expect(grouped.keys.toList(), equals(['1447', '1448']));
      expect(grouped['1447'], equals(['ذو القعدة', 'ذو الحجة']));
      expect(grouped['1448'], equals(['محرم', 'صفر']));
    });

    test('monthsByYear لشهر واحد: سنة واحدة بشهر واحد', () {
      final grouped = const HijriMonthRange(from: _rajab1448, to: _rajab1448).monthsByYear;
      expect(grouped, equals({'1448': ['رجب']}));
    });

    test('monthsByYear: سنة كاملة 12 شهراً (حدّ in في Firestore 30)', () {
      final grouped = const HijriMonthRange(
        from: HijriMonthPeriod(month: 'محرم', year: '1447'),
        to: HijriMonthPeriod(month: 'ذو الحجة', year: '1447'),
      ).monthsByYear;
      expect(grouped.keys.toList(), equals(['1447']));
      expect(grouped['1447'], hasLength(12));
    });

    test('شهر غير معروف: periods لا تدخل حلقة لا نهائية', () {
      const bad = HijriMonthPeriod(month: 'غير معروف', year: '1448');
      expect(const HijriMonthRange(from: bad, to: bad).periods, equals([bad]));
    });
  });

  group('HijriMonthRange — contains وlabel', () {
    const range = HijriMonthRange(from: _dhulHijjah1447, to: _safar1448);

    test('contains يشمل الطرفين وما بينهما فقط', () {
      expect(range.contains(_dhulHijjah1447), isTrue);
      expect(range.contains(_muharram1448), isTrue);
      expect(range.contains(_safar1448), isTrue);
      expect(range.contains(_dhulQidah1447), isFalse);
      expect(range.contains(_jumada1_1448), isFalse);
    });

    test('contains يرفض الشهر غير الصالح', () {
      expect(range.contains(const HijriMonthPeriod(month: 'غير معروف', year: '1448')), isFalse);
    });

    test('label لشهر واحد', () {
      expect(const HijriMonthRange(from: _rajab1448, to: _rajab1448).label, equals('رجب 1448هـ'));
    });

    test('label لفترة داخل سنة واحدة', () {
      expect(
        const HijriMonthRange(from: _jumada1_1448, to: _jumada2_1448).label,
        equals('من جمادى الأولى إلى جمادى الآخرة 1448هـ'),
      );
    });

    test('label لفترة تعبر السنة', () {
      expect(range.label, equals('من ذو الحجة 1447هـ إلى صفر 1448هـ'));
    });
  });
}
