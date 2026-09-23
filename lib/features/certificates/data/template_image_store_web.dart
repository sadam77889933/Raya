import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:uuid/uuid.dart';

/// الويب: لا يوجد نظام ملفات إطلاقاً، فصورة الخلفية تُحفَظ كبايتات خام
/// مباشرة داخل `IndexedDB` (قاعدة بيانات المتصفح المحلية) بدل ملف على
/// القرص. مفتاح كل مُدخَل هو `mosqueId/id.extension` — نفس شكل المسار
/// المحلي على بقية المنصات تقريباً، لكنه هنا مجرد مفتاح منطقي لا مسار
/// حقيقي (راجع تعليق [TemplateImageStore] حول عدم الاعتماد على بنيته).
const String _dbName = 'certificate_templates_imported';
const String _storeName = 'images';
const int _dbVersion = 1;

Future<Database> _openDb() async {
  final factory = getIdbFactory();
  if (factory == null) {
    throw StateError(
      'IndexedDB غير مدعوم في هذا المتصفح — تعذَّر حفظ/قراءة صورة القالب.',
    );
  }
  return factory.open(
    _dbName,
    version: _dbVersion,
    onUpgradeNeeded: (event) {
      final db = event.database;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    },
  );
}

Future<String> saveImpl({
  required String mosqueId,
  required Uint8List bytes,
  required String extension,
}) async {
  final db = await _openDb();
  final id = const Uuid().v4();
  final key = '$mosqueId/$id.$extension';
  try {
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).put(bytes, key);
    await txn.completed;
    return key;
  } finally {
    db.close();
  }
}

Future<Uint8List> loadBytesImpl(String reference) async {
  final db = await _openDb();
  try {
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final result = await txn.objectStore(_storeName).getObject(reference);
    await txn.completed;
    if (result == null) {
      throw StateError('صورة القالب غير موجودة في IndexedDB: $reference');
    }
    return result as Uint8List;
  } finally {
    db.close();
  }
}

Future<void> deleteImpl(String reference) async {
  try {
    final db = await _openDb();
    try {
      final txn = db.transaction(_storeName, idbModeReadWrite);
      await txn.objectStore(_storeName).delete(reference);
      await txn.completed;
    } finally {
      db.close();
    }
  } catch (_) {
    // فشل الحذف لا يجب أن يمنع حذف السجل من الفهرس.
  }
}

Widget buildImageImpl(String reference, {required BoxFit fit}) {
  return FutureBuilder<Uint8List>(
    future: loadBytesImpl(reference),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox.shrink();
      }
      return Image.memory(snapshot.data!, fit: fit);
    },
  );
}

Future<Uint8List> readPickedFileBytesImpl(String path) {
  throw UnsupportedError('لا مسارات ملفات على الويب.');
}
