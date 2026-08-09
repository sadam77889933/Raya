import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/roster_student.dart';

/// صف طالبة واحدة داخل المجموعة — يطابق تصميم المعاينة المتفق عليها
class RosterStudentRow extends StatelessWidget {
  final RosterStudent student;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final bool isLast;

  const RosterStudentRow({
    super.key,
    required this.student,
    required this.onToggle,
    required this.onEdit,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = student.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.green : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                student.name,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: isActive ? Colors.black87 : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Switch(
              value: isActive,
              onChanged: (_) => onToggle(),
              activeColor: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}