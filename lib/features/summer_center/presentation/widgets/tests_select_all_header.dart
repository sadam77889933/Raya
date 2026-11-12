import 'package:flutter/material.dart';

import '../../domain/services/tests_selection.dart';

/// رأس قائمة الاختبارات: خانة «تحديد الكل» (للنتائج الظاهرة فقط) وعدّاد
/// يُظهر عدد الاختبارات، أو عدد المحدَّد منها إن وُجد تحديد.
class TestsSelectAllHeader extends StatelessWidget {
  final SelectAllState state;
  final int total;
  final int selectedCount;
  final VoidCallback onToggleAll;

  const TestsSelectAllHeader({
    super.key,
    required this.state,
    required this.total,
    required this.selectedCount,
    required this.onToggleAll,
  });

  bool? get _checkboxValue => switch (state) {
        SelectAllState.all => true,
        SelectAllState.partial => null,
        SelectAllState.none => false,
      };

  String get _countLabel {
    if (selectedCount > 0) return '$selectedCount محدد من $total';
    return total == 1 ? 'اختبار واحد' : '$total اختبارات';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggleAll,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  tristate: true,
                  value: _checkboxValue,
                  onChanged: (_) => onToggleAll(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text('تحديد الكل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text(_countLabel, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade500)),
      ],
    );
  }
}
