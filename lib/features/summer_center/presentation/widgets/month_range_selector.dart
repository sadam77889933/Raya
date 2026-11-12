import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/hijri_month_period.dart';
import '../../domain/entities/hijri_month_range.dart';

/// عدد الأشهر السابقة (قبل الشهر الحالي) التي تعرضها نافذة اختيار الشهر.
const int kPreviousMonthsShown = 36;

/// يفتح نافذة اختيار شهر هجري (الشهر الحالي أولاً ثم [kPreviousMonthsShown]
/// شهراً سابقاً)، ويُعيد الشهر المختار أو null إن أُغلقت النافذة بلا اختيار.
Future<HijriMonthPeriod?> showMonthPickerSheet(
  BuildContext context, {
  required String title,
  required HijriMonthPeriod current,
  required HijriMonthPeriod selected,
}) {
  return showModalBottomSheet<HijriMonthPeriod>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MonthPickerSheet(
      title: title,
      current: current,
      selected: selected,
    ),
  );
}

/// فلتر الفترة في شاشة اختبارات المعلمات: حقلان «من» و«إلى» (شهران هجريان)،
/// وزر للعودة إلى الافتراضي (الشهر الحالي والسابق) يظهر فقط عند تغيير الفترة.
///
/// اختيار «من» بعد «إلى» (أو «إلى» قبل «من») يضبط الطرف الآخر تلقائياً
/// ليبقى النطاق صحيحاً، انظر [HijriMonthRange.withFrom] و[HijriMonthRange.withTo].
class MonthRangeSelector extends StatelessWidget {
  final HijriMonthRange range;
  final HijriMonthPeriod current;
  final ValueChanged<HijriMonthRange> onChanged;

  const MonthRangeSelector({
    super.key,
    required this.range,
    required this.current,
    required this.onChanged,
  });

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showMonthPickerSheet(
      context,
      title: 'شهر البداية',
      current: current,
      selected: range.from,
    );
    if (picked != null && picked != range.from) onChanged(range.withFrom(picked));
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showMonthPickerSheet(
      context,
      title: 'شهر النهاية',
      current: current,
      selected: range.to,
    );
    if (picked != null && picked != range.to) onChanged(range.withTo(picked));
  }

  @override
  Widget build(BuildContext context) {
    final recent = HijriMonthRange.recent(current: current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MonthField(
                label: 'من',
                period: range.from,
                onTap: () => _pickFrom(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MonthField(
                label: 'إلى',
                period: range.to,
                onTap: () => _pickTo(context),
              ),
            ),
          ],
        ),
        if (range != recent)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              onPressed: () => onChanged(recent),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text(
                'الشهر الحالي والسابق',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// حقل يعرض شهراً ويفتح نافذة الاختيار عند الضغط؛ النص يصغُر ليتسع بدل أن
/// يُقتطع على الهواتف الضيقة.
class _MonthField extends StatelessWidget {
  final String label;
  final HijriMonthPeriod period;
  final VoidCallback onTap;

  const _MonthField({
    required this.label,
    required this.period,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  period.label,
                  maxLines: 1,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatelessWidget {
  final String title;
  final HijriMonthPeriod current;
  final HijriMonthPeriod selected;

  const _MonthPickerSheet({
    required this.title,
    required this.current,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final previous = current.previousMonths(kPreviousMonthsShown);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _MonthTile(period: current, isCurrent: true, isSelected: selected == current),
                  const Divider(height: 1),
                  for (final period in previous)
                    _MonthTile(period: period, isCurrent: false, isSelected: selected == period),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  final HijriMonthPeriod period;
  final bool isCurrent;
  final bool isSelected;

  const _MonthTile({required this.period, required this.isCurrent, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        period.label,
        style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500),
      ),
      subtitle: isCurrent ? const Text('الشهر الحالي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5)) : null,
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen) : null,
      onTap: () => Navigator.of(context).pop(period),
    );
  }
}
