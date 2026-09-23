import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/imported_certificate_template.dart';

/// الويب: لا مجلد وثائق تطبيق حقيقياً (`path_provider` غير مدعوم أصلاً
/// هناك)، فالفهرس الصغير (بيانات وصفية فقط — لا صور) يُحفَظ عبر
/// `shared_preferences` بدل ملف `index.json`. لا مخاوف توافق رجعي هنا:
/// الويب لم يعمل إطلاقاً قبل هذه الميزة فلا بيانات قديمة لترحيلها.
String _prefsKey(String mosqueId) =>
    'imported_certificate_templates_$mosqueId';

Future<List<ImportedCertificateTemplate>> getForMosqueImpl(
    String mosqueId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey(mosqueId));
  if (raw == null) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final result = <ImportedCertificateTemplate>[];
    for (final e in decoded) {
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
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _prefsKey(mosqueId),
    jsonEncode(list.map((t) => t.toJson()).toList()),
  );
}
