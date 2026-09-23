import 'dart:typed_data';

/// عنصر واحد قابل للمشاركة: بايتات ملف PDF جاهزة في الذاكرة مع اسم
/// الملف الذي يجب أن يظهر للمستخدم عند المشاركة أو الحفظ.
class PdfShareItem {
  final Uint8List bytes;
  final String fileName;

  const PdfShareItem({required this.bytes, required this.fileName});
}
