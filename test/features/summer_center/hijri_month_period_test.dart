import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/core/constants/quran_constants.dart';
import 'package:quran_circle_report/features/summer_center/domain/entities/hijri_month_period.dart';

void main() {
  group('HijriMonthPeriod', () {
    test('fromNumbers يبني اسم الشهر والسنة بصيغة المخزَّن في الاختبار', () {
      final period = HijriMonthPeriod.fromNumbers(monthNumber: 7, year: 1448);
      expect(period.month, equals('رجب'));
      expect(period.year, equals('1448'));
      expect(period, equals(const HijriMonthPeriod(month: 'رجب', year: '1448')));
    });

    test('label بنفس صيغة ورقة الاختبار', () {
      const period = HijriMonthPeriod(month: 'ربيع الآخر', year: '1448');
      expect(period.label, equals('ربيع الآخر 1448هـ'));
    });

    test('current يُعيد شهراً معروفاً وسنة رقمية', () {
      final period = HijriMonthPeriod.current();
      expect(QuranConstants.hijriMonths.contains(period.month), isTrue);
      expect(int.tryParse(period.year), isNotNull);
    });

    test('previous داخل السنة نفسها', () {
      const period = HijriMonthPeriod(month: 'رجب', year: '1448');
      expect(period.previous(), equals(const HijriMonthPeriod(month: 'جمادى الآخرة', year: '1448')));
    });

    test('previous يعبر حدود السنة (محرم ← ذو الحجة من السنة السابقة)', () {
      const period = HijriMonthPeriod(month: 'محرم', year: '1448');
      expect(period.previous(), equals(const HijriMonthPeriod(month: 'ذو الحجة', year: '1447')));
    });

    test('next داخل السنة نفسها', () {
      const period = HijriMonthPeriod(month: 'رجب', year: '1448');
      expect(period.next(), equals(const HijriMonthPeriod(month: 'شعبان', year: '1448')));
    });

    test('next يعبر حدود السنة (ذو الحجة ← محرم من السنة التالية)', () {
      const period = HijriMonthPeriod(month: 'ذو الحجة', year: '1447');
      expect(period.next(), equals(const HijriMonthPeriod(month: 'محرم', year: '1448')));
    });

    test('next معكوس previous لكل أشهر السنة', () {
      for (final month in QuranConstants.hijriMonths) {
        final period = HijriMonthPeriod(month: month, year: '1448');
        expect(period.next().previous(), equals(period), reason: month);
        expect(period.previous().next(), equals(period), reason: month);
      }
    });

    test('key يزيد بواحد بالضبط مع كل شهر عبر حدود السنوات', () {
      var cursor = const HijriMonthPeriod(month: 'ذو القعدة', year: '1446');
      for (var i = 0; i < 30; i++) {
        final next = cursor.next();
        expect(next.key, equals(cursor.key + 1), reason: '${cursor.label} ← ${next.label}');
        cursor = next;
      }
    });

    test('isValid: اسم شهر معروف وسنة رقمية فقط', () {
      expect(const HijriMonthPeriod(month: 'رجب', year: '1448').isValid, isTrue);
      expect(const HijriMonthPeriod(month: 'غير معروف', year: '1448').isValid, isFalse);
      expect(const HijriMonthPeriod(month: 'رجب', year: 'abc').isValid, isFalse);
    });

    test('previousMonths بالترتيب من الأحدث إلى الأقدم دون الشهر نفسه', () {
      const period = HijriMonthPeriod(month: 'رجب', year: '1448');
      final months = period.previousMonths(24);

      expect(months, hasLength(24));
      expect(months.contains(period), isFalse);
      expect(months.first, equals(const HijriMonthPeriod(month: 'جمادى الآخرة', year: '1448')));
      expect(months.last, equals(const HijriMonthPeriod(month: 'رجب', year: '1446')));

      final keys = [for (final m in months) QuranConstants.hijriPeriodKey(m.month, m.year)];
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i], equals(keys[i - 1] - 1), reason: 'كل شهر يسبق السابق له بشهر واحد بالضبط');
      }
      expect(months.toSet(), hasLength(24));
    });

    test('previousMonths(0) قائمة فارغة', () {
      const period = HijriMonthPeriod(month: 'رجب', year: '1448');
      expect(period.previousMonths(0), isEmpty);
    });

    test('اسم شهر غير معروف: previous وnext يُعيدان الشهر نفسه وpreviousMonths فارغة', () {
      const period = HijriMonthPeriod(month: 'غير معروف', year: '1448');
      expect(period.previous(), equals(period));
      expect(period.next(), equals(period));
      expect(period.previousMonths(5), isEmpty);
    });

    test('سنة غير رقمية عند حدّ السنة: previous وnext لا ينهاران', () {
      const first = HijriMonthPeriod(month: 'محرم', year: 'abc');
      const last = HijriMonthPeriod(month: 'ذو الحجة', year: 'abc');
      expect(first.previous(), equals(first));
      expect(last.next(), equals(last));
    });
  });
}
