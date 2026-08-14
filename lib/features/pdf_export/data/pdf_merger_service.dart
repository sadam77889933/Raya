import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// دمج عدة ملفات PDF جاهزة (كل واحد كصفحاته الأصلية كاملة)
/// إلى ملف واحد نهائي — لا يُغيّر أي محتوى، فقط يُلحق الصفحات
class PdfMergerService {
  /// يستقبل قائمة مسارات ملفات PDF، ويُعيد مسار الملف المُدمَج
  Future<String> mergePdfs(
    List<String> pdfPaths, {
    required String outputFileName,
  }) async {
    final mergedDocument = PdfDocument();
    mergedDocument.pages.removeAt(0);

    // نضبط إعدادات الصفحة الافتراضية لتطابق A4 المستخدم في PdfGenerator
    mergedDocument.pageSettings.size =
        const Size(595.15, 842.01);
    mergedDocument.pageSettings.margins.all = 0;

    for (final path in pdfPaths) {
      final bytes = await File(path).readAsBytes();
      final sourceDocument = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < sourceDocument.pages.count; i++) {
        final sourcePage = sourceDocument.pages[i];
        final pageSize = sourcePage.size;
        final template = sourcePage.createTemplate();

        final newPage = mergedDocument.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          Size(pageSize.width, pageSize.height),
        );
      }

      sourceDocument.dispose();
    }

    final bytes = await mergedDocument.save();
    mergedDocument.dispose();

    final dir = await getTemporaryDirectory();
    final outputFile = File('${dir.path}/$outputFileName');
    await outputFile.writeAsBytes(bytes);

    return outputFile.path;
  }
}