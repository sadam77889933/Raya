import 'package:share_plus/share_plus.dart';

import 'pdf_share_item.dart';

/// على الويب لا يوجد نظام ملفات، فتُشارَك البايتات مباشرة عبر
/// `XFile.fromData` — وهذا يعمل بشكل صحيح وموثوق على هذه المنصة
/// تحديداً (خلافاً لويندوز، راجع pdf_share_service_io.dart).
Future<void> sharePdfFilesImpl(
  List<PdfShareItem> items, {
  String? subject,
}) {
  final files = items
      .map((item) => XFile.fromData(
            item.bytes,
            name: item.fileName,
            mimeType: 'application/pdf',
          ))
      .toList();
  return Share.shareXFiles(files, subject: subject);
}
