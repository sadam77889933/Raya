import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// طريقة إضافة طالبة إلى تقرير قيد التعديل.
enum AddStudentOption { newStudent, fromRoster }

/// يعرض خياري الإضافة ويُرجع اختيار المعلمة، أو null إن أُغلقت الورقة.
///
/// [rosterAvailable] = false يعطّل خيار السجل، كما في التقارير القديمة التي
/// لا تحمل معرّف حلقة فلا يُعرف أي سجل تُختار منه الطالبة.
Future<AddStudentOption?> showAddStudentOptionsSheet(
  BuildContext context, {
  required bool rosterAvailable,
}) {
  return showModalBottomSheet<AddStudentOption>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _AddStudentOptionsSheet(rosterAvailable: rosterAvailable),
  );
}

class _AddStudentOptionsSheet extends StatelessWidget {
  final bool rosterAvailable;

  const _AddStudentOptionsSheet({required this.rosterAvailable});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إضافة طالبة إلى التقرير',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'إضافة طالبة جديدة',
              subtitle: 'اكتبي اسمها، وتُضاف إلى سجل الحلقة عند حفظ التقرير',
              onTap: () =>
                  Navigator.of(context).pop(AddStudentOption.newStudent),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.groups_rounded,
              title: 'إضافة طالبة موجودة في سجل الحلقة',
              subtitle: rosterAvailable
                  ? 'اختاري من الطالبات المسجّلات في الحلقة'
                  : 'غير متاح: هذا التقرير غير مرتبط بحلقة',
              onTap: rosterAvailable
                  ? () =>
                      Navigator.of(context).pop(AddStudentOption.fromRoster)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      enabled: onTap != null,
      tileColor: AppTheme.lightGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
