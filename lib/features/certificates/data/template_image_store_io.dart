import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// أندرويد / iOS / ويندوز / macOS / لينكس: صورة الخلفية تُحفَظ كملف
/// حقيقي داخل مجلد وثائق التطبيق، كل مسجد في مجلد فرعي منفصل بمعرِّفه —
/// نفس ما كان عليه `ImportedCertificateTemplateRepositoryImpl` سابقاً قبل
/// فصل هذه الطبقة عنه.
Future<Directory> _mosqueDir(String mosqueId) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir =
      Directory('${docsDir.path}/certificate_templates_imported/$mosqueId');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String> saveImpl({
  required String mosqueId,
  required Uint8List bytes,
  required String extension,
}) async {
  final dir = await _mosqueDir(mosqueId);
  final id = const Uuid().v4();
  final path = '${dir.path}/$id.$extension';
  await File(path).writeAsBytes(bytes);
  return path;
}

Future<Uint8List> loadBytesImpl(String reference) =>
    File(reference).readAsBytes();

Future<void> deleteImpl(String reference) async {
  try {
    final file = File(reference);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // فشل حذف الملف لا يجب أن يمنع حذف السجل من الفهرس.
  }
}

Widget buildImageImpl(String reference, {required BoxFit fit}) {
  return Image.file(File(reference), fit: fit);
}

Future<Uint8List> readPickedFileBytesImpl(String path) =>
    File(path).readAsBytes();
