import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

/// يحوِّل ملفاً مستورَداً (صورة أو PDF) إلى صورة محفوظة محلياً داخل مجلد
/// وثائق التطبيق، جاهزة لتُستخدَم كـ`localBackgroundImagePath` لقالب
/// مستورَد جديد — القسم ٦ من تصميم الميزة (استيراد قوالب).
///
/// ملف PDF: يُحوَّل إلى صورة الصفحة الأولى فقط (`Printing.raster` من
/// حزمة `printing`، المُستخدَمة أصلاً في مكان آخر بالمشروع)، بدقة طباعة
/// مناسبة (٢٠٠ نقطة/إنش — الافتراضي ٧٢ غير كافٍ إطلاقاً لجودة طباعة
/// شهادة). ملف صورة: يُنسَخ كما هو بايتاً بايت بلا أي إعادة ترميز، تفادياً
/// لأي فقد جودة إضافي لا داعي له.
class CertificateTemplateImportService {
  static Future<String> importFile({
    required String mosqueId,
    required Uint8List bytes,
    required bool isPdf,
    String imageExtension = 'png',
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir =
        Directory('${docsDir.path}/certificate_templates_imported/$mosqueId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final id = const Uuid().v4();

    final Uint8List finalBytes;
    final String extension;
    if (isPdf) {
      final raster = await Printing.raster(bytes, pages: const [0], dpi: 200)
          .first;
      finalBytes = await raster.toPng();
      extension = 'png';
    } else {
      finalBytes = bytes;
      extension = imageExtension.isEmpty ? 'png' : imageExtension;
    }

    final destPath = '${dir.path}/$id.$extension';
    await File(destPath).writeAsBytes(finalBytes);
    return destPath;
  }
}
