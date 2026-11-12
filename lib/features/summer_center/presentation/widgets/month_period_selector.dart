import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/hijri_month_period.dart';

/// عدد الأشهر السابقة التي تعرضها نافذة «الأشهر السابقة».
const int kPreviousMonthsShown = 24;

/// يفتح نافذة اختيار شهر من الأشهر السابقة، ويُعيد الشهر المختار (أو null
/// إن أُغلقت النافذة بلا اختيار). الشهر الحالي في أولها دائماً للعودة إليه.
Future<HijriMonthPeriod?> showPastMonthsSheet(
  BuildContext context, {
  required HijriMonthPeriod current,
  required HijriMonthPeriod selected,
}) {
  return showModalBottomSheet<HijriMonthPeriod>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PastMonthsSheet(current: current, selected: selected),
  );
}

/// فلتر الشهر في شاشة اختبارات المعلمات: يعرض الشهر المحدَّد (الشهر الحالي
/// افتراضياً)، وزر «عرض الأشهر السابقة» لاختيار شهر أقدم.
class MonthPeriodSelector extends StatelessWidget {
  final HijriMonthPeriod selected;
  final HijriMonthPeriod current;
  final ValueChanged<HijriMonthPeriod> onChanged;

  const MonthPeriodSelector({
    super.key,
    required this.selected,
    required this.current,
    required this.onChanged,
  });

  Future<void> _openPastMonths(BuildContext context) async {
    final picked = await showPastMonthsSheet(
      context,
      current: current,
      selected: selected,
    );
    if (picked != null && picked != selected) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = selected == current;
    // الزر تحت الخانة (لا بجانبها) كي لا يُقتطع اسم الشهر على الهواتف الضيقة.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: const InputDecoration(labelText: 'الشهر', isDense: true),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              if (isCurrent) const _CurrentMonthTag(),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            onPressed: () => _openPastMonths(context),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('عرض الأشهر السابقة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5)),
          ),
        ),
      ],
    );
  }
}

class _CurrentMonthTag extends StatelessWidget {
  const _CurrentMonthTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'الحالي',
        style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: AppTheme.primaryGreen, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PastMonthsSheet extends StatelessWidget {
  final HijriMonthPeriod current;
  final HijriMonthPeriod selected;

  const _PastMonthsSheet({required this.current, required this.selected});

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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('اختيار الشهر', style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w800)),
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
