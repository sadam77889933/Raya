import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/summer_tests_export_service.dart';

/// حوار تقدّم تجهيز ملف PDF لعدة اختبارات، مع زر «إلغاء». لا يُغلَق من
/// الخارج ولا بزر الرجوع؛ يُغلقه المستدعي عند انتهاء العملية أو إلغائها.
class ExportProgressDialog extends StatefulWidget {
  final ValueListenable<SummerTestsExportProgress> progress;
  final VoidCallback onCancel;

  const ExportProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  bool _cancelling = false;

  void _handleCancel() {
    setState(() => _cancelling = true);
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('تجهيز ملف PDF', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w800)),
        content: ValueListenableBuilder<SummerTestsExportProgress>(
          valueListenable: widget.progress,
          builder: (context, progress, _) {
            final building = progress.total > 0 && progress.done >= progress.total;
            final label = building
                ? 'جارٍ إنشاء الملف…'
                : 'جارٍ تجهيز الاختبار ${progress.done + 1} من ${progress.total}';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: building ? null : progress.fraction),
                const SizedBox(height: 14),
                Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                if (progress.currentTitle.isNotEmpty && !building) ...[
                  const SizedBox(height: 4),
                  Text(
                    progress.currentTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: _cancelling ? null : _handleCancel,
            child: Text(_cancelling ? 'جارٍ الإلغاء…' : 'إلغاء'),
          ),
        ],
      ),
    );
  }
}
