import 'package:flutter/material.dart';

/// شريط سفلي يظهر عند وجود اختبارات محدَّدة: زر «تصدير PDF» بعدد المحدَّد،
/// وتنبيه (مع تعطيل الزر) إن تجاوز العدد الحد الأقصى للملف الواحد.
class TestsExportBar extends StatelessWidget {
  final int selectedCount;
  final int maxCount;
  final bool isExporting;
  final VoidCallback onExport;

  const TestsExportBar({
    super.key,
    required this.selectedCount,
    required this.maxCount,
    required this.isExporting,
    required this.onExport,
  });

  bool get _overLimit => selectedCount > maxCount;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_overLimit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'الحد الأقصى $maxCount اختبارًا في الملف الواحد — قلّلي التحديد ثم صدّري.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: errorColor),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: (_overLimit || isExporting) ? null : onExport,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                label: Text('تصدير PDF ($selectedCount)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
