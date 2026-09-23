import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// حفظ بيانات تسجيل الدخول محلياً بشكل مُشفَّر (اختياري بموافقة المستخدمة)
///
/// القرار الأمني: نستخدم flutter_secure_storage (وليس SharedPreferences)
/// لأنها تُشفّر البيانات باستخدام آليات نظام التشغيل نفسه (Keystore على
/// أندرويد)، بخلاف SharedPreferences التي تُخزّن كنص عادي غير محمي.
///
/// **استثناء الويب:** تنفيذ هذه الحزمة على الويب يخزّن مفتاح التشفير
/// وبيانات المستخدمة معاً داخل متصفح الجهاز نفسه (IndexedDB)، بخلاف
/// أندرويد حيث المفتاح مربوط بـKeystore على مستوى نظام التشغيل. أي شخص
/// له وصول لنفس ملف تعريف المتصفح (جهاز مشترك، أو أدوات المطوّر) يمكنه
/// استخراج كلمة المرور الفعلية بسهولة أكبر بكثير. لذلك تُعطَّل ميزة
/// "تذكرني" على الويب تحديداً فقط (بلا أي تغيير على سلوك أندرويد/iOS).
class CredentialsStorageService {
  final _storage = const FlutterSecureStorage();

  static const _emailKey = 'saved_email';
  static const _passwordKey = 'saved_password';
  static const _rememberMeKey = 'remember_me';

  Future<void> saveCredentials(String email, String password) async {
    if (kIsWeb) return;
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _rememberMeKey, value: 'true');
  }

  Future<void> clearCredentials() async {
    // تُترَك فعّالة على كل المنصات (بما فيها الويب) عمداً: لو كانت هناك
    // بيانات محفوظة من قبل (مثلاً من اختبار سابق)، هذا يضمن مسحها فعلياً.
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _rememberMeKey);
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    if (kIsWeb) return null;

    final rememberMe = await _storage.read(key: _rememberMeKey);
    if (rememberMe != 'true') return null;

    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);

    if (email == null || password == null) return null;

    return {'email': email, 'password': password};
  }

  Future<bool> isRememberMeEnabled() async {
    if (kIsWeb) return false;
    final value = await _storage.read(key: _rememberMeKey);
    return value == 'true';
  }
}