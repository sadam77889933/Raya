import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/entities/imported_certificate_template.dart';
import '../domain/repositories/imported_certificate_template_repository.dart';

/// تنفيذ محلي بحت لمستودع القوالب المستورَدة — لا Firestore ولا Firebase
/// Storage إطلاقاً (قرار مقصود اعتمدته المستخدمة: صفر تكلفة تخزين سحابي،
/// مقابل فقدان القوالب المستورَدة عند حذف التطبيق أو تغيير الجهاز). صورة
/// الخلفية + فهرس JSON صغير يُحفَظان معاً داخل مجلد وثائق التطبيق الخاص
/// (`path_provider`)، كل مسجد في مجلد فرعي منفصل بمعرِّفه — بمعزل كامل عن
/// أي مسجد آخر قد يُسجَّل دخوله لاحقاً من نفس الجهاز.
class ImportedCertificateTemplateRepositoryImpl
    implements ImportedCertificateTemplateRepository {
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

  @override
  Future<List<ImportedCertificateTemplate>> getForMosque(
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

  @override
  Future<void> add(ImportedCertificateTemplate template) async {
    final list = await getForMosque(template.mosqueId);
    final updated = [...list, template];
    await _saveIndex(template.mosqueId, updated);
  }

  @override
  Future<void> delete(String mosqueId, String templateId) async {
    final list = await getForMosque(mosqueId);
    ImportedCertificateTemplate? target;
    for (final t in list) {
      if (t.id == templateId) {
        target = t;
        break;
      }
    }
    final updated = list.where((t) => t.id != templateId).toList();
    await _saveIndex(mosqueId, updated);
    if (target != null) {
      try {
        final imageFile = File(target.backgroundImagePath);
        if (await imageFile.exists()) await imageFile.delete();
      } catch (_) {
        // فشل حذف ملف الصورة لا يجب أن يمنع حذف السجل من الفهرس.
      }
    }
  }

  Future<void> _saveIndex(
      String mosqueId, List<ImportedCertificateTemplate> list) async {
    final file = await _indexFile(mosqueId);
    await file
        .writeAsString(jsonEncode(list.map((t) => t.toJson()).toList()));
  }
}
