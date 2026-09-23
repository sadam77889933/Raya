import 'dart:typed_data';

import 'pdf_share_item.dart';
import 'pdf_share_service_web.dart'
    if (dart.library.io) 'pdf_share_service_io.dart' as impl;

export 'pdf_share_item.dart' show PdfShareItem;

/// يشارك عدة ملفات PDF (كبايتات جاهزة في الذاكرة) دفعة واحدة عبر شاشة
/// المشاركة الأصلية للنظام، مع ضمان ظهور اسم كل ملف بشكل صحيح على كل
/// المنصات المستهدَفة (أندرويد / iOS / ويندوز / macOS / لينكس / الويب).
/// راجع التوثيق في pdf_share_service_io.dart لتفاصيل السبب التقني وراء
/// اختلاف التنفيذ بين الويب وبقية المنصات.
Future<void> sharePdfFiles(
  List<PdfShareItem> items, {
  String? subject,
}) =>
    impl.sharePdfFilesImpl(items, subject: subject);

/// اختصار لمشاركة ملف PDF واحد فقط — الحالة الأكثر شيوعاً في التطبيق.
Future<void> sharePdfBytes(
  Uint8List bytes, {
  required String fileName,
  String? subject,
}) =>
    sharePdfFiles(
      [PdfShareItem(bytes: bytes, fileName: fileName)],
      subject: subject,
    );
