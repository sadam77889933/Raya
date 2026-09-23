import 'url_strategy_web.dart' if (dart.library.io) 'url_strategy_io.dart'
    as impl;

/// نقطة الدخول الموحَّدة: على الويب تُفعِّل روابط المسار النظيفة، وعلى
/// أي منصّة أخرى لا تفعل شيئاً. استخدام Conditional Import قياسي
/// (بنفس أسلوب lib/core/services/pdf_share_service.dart) بدل استيراد
/// `flutter_web_plugins` مباشرة في main.dart لتفادي أي افتراض غير مؤكَّد
/// حول توافق استيرادها على كل أهداف تصريف الويب (JS مقابل WASM).
void configureUrlStrategy() => impl.configureUrlStrategy();
