import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersionName;
  final String downloadUrl;
  final bool isForced;
  final String releaseNotes;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.isForced,
    required this.releaseNotes,
  });

  static const noUpdate = UpdateInfo(
    hasUpdate: false,
    latestVersionName: '',
    downloadUrl: '',
    isForced: false,
    releaseNotes: '',
  );
}

class UpdateCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final doc =
          await _firestore.collection('app_config').doc('version').get();

      if (!doc.exists) return UpdateInfo.noUpdate;

      final data = doc.data()!;
      final latestVersionCode = data['latestVersionCode'] as int? ?? 0;

      if (latestVersionCode <= currentVersionCode) {
        return UpdateInfo.noUpdate;
      }

      return UpdateInfo(
        hasUpdate: true,
        latestVersionName: data['latestVersionName'] as String? ?? '',
        downloadUrl: data['downloadUrl'] as String? ?? '',
        isForced: data['isForced'] as bool? ?? false,
        releaseNotes: data['releaseNotes'] as String? ?? '',
      );
    } catch (_) {
      return UpdateInfo.noUpdate;
    }
  }
}