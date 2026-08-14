import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker_service.dart';
import '../theme/app_theme.dart';

/// نافذة إشعار التحديث — تظهر تلقائياً عند وجود إصدار أحدث
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> showIfNeeded(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    if (!updateInfo.hasUpdate) return;

    await showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      builder: (_) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  Future<void> _openDownloadLink() async {
    final uri = Uri.parse(updateInfo.downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: AppTheme.primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'يوجد تحديث جديد',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'الإصدار ${updateInfo.latestVersionName} متوفر الآن',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (updateInfo.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                updateInfo.releaseNotes,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (!updateInfo.isForced)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'لاحقاً',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ElevatedButton.icon(
          onPressed: _openDownloadLink,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('تحديث الآن'),
        ),
      ],
    );
  }
}