import 'package:equatable/equatable.dart';

import 'hijri_month_period.dart';

/// فترة من شهر هجري إلى شهر هجري (شاملة الطرفين) — فلتر «من/إلى» في شاشة
/// اختبارات المعلمات. البداية دائماً ≤ النهاية؛ تحافظ [withFrom] و[withTo]
/// على هذا الشرط تلقائياً.
class HijriMonthRange extends Equatable {
  /// أقصى عدد أشهر تُعدِّدها [periods]، حمايةً من نطاق فاسد.
  static const int _maxPeriods = 240;

  final HijriMonthPeriod from;
  final HijriMonthPeriod to;

  const HijriMonthRange({required this.from, required this.to});

  /// من [a] و[b] بأي ترتيب: الأقدم هو البداية.
  factory HijriMonthRange.ordered(HijriMonthPeriod a, HijriMonthPeriod b) {
    return a.key <= b.key
        ? HijriMonthRange(from: a, to: b)
        : HijriMonthRange(from: b, to: a);
  }

  /// الافتراضي عند فتح الشاشة: الشهر السابق ثم الشهر الحالي.
  factory HijriMonthRange.recent({HijriMonthPeriod? current}) {
    final now = current ?? HijriMonthPeriod.current();
    return HijriMonthRange(from: now.previous(), to: now);
  }

  bool get isSingleMonth => from == to;

  /// يغيّر البداية؛ إن صارت بعد النهاية تصير النهاية هي نفسها.
  HijriMonthRange withFrom(HijriMonthPeriod value) {
    return value.key > to.key
        ? HijriMonthRange(from: value, to: value)
        : HijriMonthRange(from: value, to: to);
  }

  /// يغيّر النهاية؛ إن صارت قبل البداية تصير البداية هي نفسها.
  HijriMonthRange withTo(HijriMonthPeriod value) {
    return value.key < from.key
        ? HijriMonthRange(from: value, to: value)
        : HijriMonthRange(from: from, to: value);
  }

  /// هل [period] داخل الفترة (شاملة الطرفين)؟
  bool contains(HijriMonthPeriod period) {
    return period.isValid && period.key >= from.key && period.key <= to.key;
  }

  /// كل أشهر الفترة من الأقدم إلى الأحدث.
  List<HijriMonthPeriod> get periods {
    final result = <HijriMonthPeriod>[];
    var cursor = from;
    while (cursor.key <= to.key && result.length < _maxPeriods) {
      result.add(cursor);
      final next = cursor.next();
      if (next == cursor) break;
      cursor = next;
    }
    return result;
  }

  /// أشهر الفترة مجمَّعة بالسنة (بترتيب السنوات ثم الأشهر)، لبناء استعلام
  /// واحد لكل سنة: `hijriYear == السنة` و`hijriMonth in أشهرها`.
  Map<String, List<String>> get monthsByYear {
    final grouped = <String, List<String>>{};
    for (final period in periods) {
      grouped.putIfAbsent(period.year, () => <String>[]).add(period.month);
    }
    return grouped;
  }

  /// نص العرض واسم الملف: «رجب 1448هـ» لشهر واحد، أو «من X إلى Y».
  String get label {
    if (isSingleMonth) return from.label;
    if (from.year == to.year) return 'من ${from.month} إلى ${to.label}';
    return 'من ${from.label} إلى ${to.label}';
  }

  @override
  List<Object?> get props => [from, to];
}
