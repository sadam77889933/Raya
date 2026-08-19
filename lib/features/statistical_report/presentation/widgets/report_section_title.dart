import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// عنوان قسم موحّد لكل أقسام التقرير الإحصائي — شريط أخضر رأسي + نص عريض،
/// بنفس النمط المستخدم فعلياً في CompanionCurriculumSelector، لضمان
/// تناسق بصري مع بقية الشاشات بدل اختراع نمط جديد.
class ReportSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const ReportSectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 15,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
