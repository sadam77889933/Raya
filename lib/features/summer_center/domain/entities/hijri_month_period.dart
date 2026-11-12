import 'package:equatable/equatable.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/constants/quran_constants.dart';

/// شهر هجري محدَّد (اسم الشهر + السنة) بنفس الصيغة المخزَّنة مع كل اختبار
/// في `SummerTest.hijriMonth` و`SummerTest.hijriYear`، فيصلح مباشرة شرطَ
/// فلترة على الخادم دون تحويل.
class HijriMonthPeriod extends Equatable {
  /// اسم الشهر كما في [QuranConstants.hijriMonths] (مثل «رجب»).
  final String month;

  /// السنة الهجرية كنص (مثل «1448»).
  final String year;

  const HijriMonthPeriod({required this.month, required this.year});

  /// من رقم الشهر (1..12) والسنة.
  factory HijriMonthPeriod.fromNumbers({
    required int monthNumber,
    required int year,
  }) {
    return HijriMonthPeriod(
      month: QuranConstants.hijriMonths[monthNumber - 1],
      year: '$year',
    );
  }

  /// الشهر الهجري الحالي — بنفس حساب `HijriCalendar.now()` المستخدم عند
  /// إنشاء الاختبار، فيتطابق الشهر المعروض مع الشهر المخزَّن دائماً.
  factory HijriMonthPeriod.current() {
    final today = HijriCalendar.now();
    return HijriMonthPeriod.fromNumbers(
      monthNumber: today.hMonth,
      year: today.hYear,
    );
  }

  /// نص العرض، بنفس صيغة ورقة الاختبار: «رجب 1448هـ».
  String get label => '$month $year' 'هـ';

  int get _monthIndex => QuranConstants.hijriMonths.indexOf(month);

  /// هل اسم الشهر معروف والسنة رقمية؟ (وإلا لا يصلح للحساب والمقارنة).
  bool get isValid => _monthIndex >= 0 && int.tryParse(year) != null;

  /// مفتاح رتيب يزيد بواحد مع كل شهر عبر حدود السنوات، للمقارنة والترتيب
  /// (انظر [QuranConstants.hijriPeriodKey]).
  int get key => QuranConstants.hijriPeriodKey(month, year);

  /// الشهر السابق مباشرة (مع عبور حدود السنة)، أو هذا الشهر نفسه إن كان
  /// اسم الشهر غير معروف.
  HijriMonthPeriod previous() {
    final index = _monthIndex;
    if (index < 0) return this;
    if (index > 0) {
      return HijriMonthPeriod(
        month: QuranConstants.hijriMonths[index - 1],
        year: year,
      );
    }
    final yearNumber = int.tryParse(year);
    if (yearNumber == null) return this;
    return HijriMonthPeriod(
      month: QuranConstants.hijriMonths.last,
      year: '${yearNumber - 1}',
    );
  }

  /// الشهر التالي مباشرة (مع عبور حدود السنة)، أو هذا الشهر نفسه إن كان
  /// اسم الشهر غير معروف.
  HijriMonthPeriod next() {
    final index = _monthIndex;
    if (index < 0) return this;
    if (index < QuranConstants.hijriMonths.length - 1) {
      return HijriMonthPeriod(
        month: QuranConstants.hijriMonths[index + 1],
        year: year,
      );
    }
    final yearNumber = int.tryParse(year);
    if (yearNumber == null) return this;
    return HijriMonthPeriod(
      month: QuranConstants.hijriMonths.first,
      year: '${yearNumber + 1}',
    );
  }

  /// [count] شهراً سابقاً لهذا الشهر، من الأحدث إلى الأقدم، دون هذا الشهر.
  List<HijriMonthPeriod> previousMonths(int count) {
    final months = <HijriMonthPeriod>[];
    var cursor = this;
    for (var i = 0; i < count; i++) {
      final next = cursor.previous();
      if (next == cursor) break;
      months.add(next);
      cursor = next;
    }
    return months;
  }

  @override
  List<Object?> get props => [month, year];
}
