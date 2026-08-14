import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels = const ['الحلقة', 'الطالبات', 'المعاينة', 'التقرير'],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIndex = (i ~/ 2) + 1;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? AppTheme.primaryGreen
                    : Colors.grey.shade200,
              ),
            );
          }
          final stepNumber = (i ~/ 2) + 1;
          final isActive = stepNumber == currentStep;
          final isCompleted = stepNumber < currentStep;

          return _StepDot(
            stepNumber: stepNumber,
            label: stepLabels[stepNumber - 1],
            isActive: isActive,
            isCompleted: isCompleted,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepDot({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 32 : 26,
          height: isActive ? 32 : 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppTheme.primaryGreen
                : isActive
                    ? AppTheme.primaryGreen
                    : Colors.grey.shade200,
            border: isActive
                ? Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 3,
                  )
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          isActive ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10,
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive
                ? AppTheme.primaryGreen
                : isCompleted
                    ? AppTheme.primaryGreen.withOpacity(0.7)
                    : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}