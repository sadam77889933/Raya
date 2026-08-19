import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// شريط مؤشر أداء أفقي بسيط (تصميم مسطّح بلا تدرّج أو ظل)، بديل عن رسوم
/// بيانية معقّدة — الوضوح قبل الزخرفة، حسب متطلبات التصميم المعتمد.
class PerformanceIndicatorBar extends StatelessWidget {
  final String label;
  final double percent; // 0-100
  final String valueLabel;
  final bool isGold; // للغياب فقط: المؤشر الوحيد "الأقل أفضل"

  const PerformanceIndicatorBar({
    super.key,
    required this.label,
    required this.percent,
    required this.valueLabel,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: clamped / 100,
                minHeight: 8,
                backgroundColor: const Color(0xFFEEF1EE),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isGold ? AppTheme.goldAccent : AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              valueLabel,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
