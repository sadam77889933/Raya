import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/entities/imported_certificate_template.dart';

/// أندرويد / iOS / ويندوز / macOS / لينكس: فهرس صغير بصيغة JSON داخل
/// نفس مجلد صور القوالب المستورَدة لكل مسجد. هذا بالضبط سلوك
/// `ImportedCertificateTemplateRepositoryImpl` الأصلي قبل فصل هذه الطبقة
/// عنه — بلا أي تغيير — حتى لا تفقد المستخدمات الحاليات على أندرويد أي
/// قالب مستورَد سابقاً.
Future<Directory> _mosqueDir(String mosqueId) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir =
      Directory('${docsDir.path}/certificate_templates_imported/$mosqueId');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<File> _indexFile(String mosqueId) async {
  final dir = await _mosqueDir(mosqueId);
  return File('${dir.path}/index.json');
}

Future<List<ImportedCertificateTemplate>> getForMosqueImpl(
    String mosqueId) async {
  final file = await _indexFile(mosqueId);
  if (!await file.exists()) return const [];
  try {
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) return const [];
    final result = <ImportedCertificateTemplate>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      try {
        result.add(ImportedCertificateTemplate.fromJson(e));
      } catch (_) {
        // سجل واحد تالف — يُتجاهَل بدل إسقاط بقية القوالب السليمة.
      }
    }
    return result;
  } catch (_) {
    return const [];
  }
}

Future<void> saveIndexImpl(
    String mosqueId, List<ImportedCertificateTemplate> list) async {
  final file = await _indexFile(mosqueId);
  await file
      .writeAsString(jsonEncode(list.map((t) => t.toJson()).toList()));
}
