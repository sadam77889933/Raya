import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/performance_rating.dart';

/// رقاقة مدمجة لعرض تقييم عام (ممتاز/جيد جداً/جيد/مقبول/ضعيف) — تُستخدم
/// في قسم "الأداء العام للحلقة". نقطة ملوّنة + نص فقط، بدون نسبة مئوية
/// مكرَّرة (النسبة مذكورة أصلاً في قسم المؤشرات أعلاه).
class RatingChip extends StatelessWidget {
  final String label;
  final String grade; // ممتاز / جيد جداً / جيد / مقبول / ضعيف / ''

  const RatingChip({super.key, required this.label, required this.grade});

  @override
  Widget build(BuildContext context) {
    final hasData = grade.isNotEmpty;
    final isHigh = PerformanceRating.isHigh(grade);
    final color = !hasData
        ? Colors.grey.shade400
        : (isHigh ? AppTheme.primaryGreen : AppTheme.goldAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(left: 5),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Text(
                hasData ? grade : '—',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: hasData ? color : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
