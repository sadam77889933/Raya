import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_share_item.dart';

/// التطبيق على أندرويد / iOS / ويندوز / macOS / لينكس: تُكتب بايتات كل
/// عنصر كملف حقيقي باسمه الصحيح في مجلد مؤقت أولاً، ثم تُشارَك بمسارها.
///
/// هذا ضروري تحديداً على ويندوز: تبيّن أن `XFile.fromData(bytes, name:
/// ...)` لا يُظهر الاسم المُمرَّر له بشكل موثوق على هذه المنصة (يظهر
/// بدلاً منه اسم عشوائي في نافذة المشاركة)، لذلك الكتابة الفعلية إلى
/// القرص باسم صحيح ثم المشاركة بالمسار هي الطريقة الموثوقة الوحيدة هنا.
Future<void> sharePdfFilesImpl(
  List<PdfShareItem> items, {
  String? subject,
}) async {
  final dir = await getTemporaryDirectory();
  final files = <XFile>[];
  for (final item in items) {
    final file = File('${dir.path}/${item.fileName}');
    await file.writeAsBytes(item.bytes);
    files.add(XFile(file.path, mimeType: 'application/pdf'));
  }
  await Share.shareXFiles(files, subject: subject);
}
