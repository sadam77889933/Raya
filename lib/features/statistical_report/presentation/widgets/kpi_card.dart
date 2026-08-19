import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// بطاقة مؤشر أداء واحدة (KPI). البطاقات "hero" (إجمالي الطالبات، متوسط
/// الحضور) أكبر حجماً وبخلفية خضراء فاتحة لإبرازها بصرياً عن الباقي —
/// إجابة أول سؤالين تحتاج المشرفة معرفتهما فوراً، بدل شبكة متجانسة
/// تُفقد القارئ الأولوية بين 8 أرقام مختلفة.
class KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isHero;

  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isHero ? AppTheme.lightGreen : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHero ? AppTheme.primaryGreen : Colors.grey.shade200,
          width: isHero ? 1.3 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: isHero ? 22 : 16,
              fontWeight: FontWeight.w800,
              color: isHero ? AppTheme.primaryGreen : Colors.black87,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isHero ? AppTheme.primaryGreen : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
