import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// يستبدل روابط الويب الافتراضية القائمة على Hash
/// (`example.com/#/route`) بروابط نظيفة (`example.com/route`) — تجميلي
/// بحت ولا يُغيّر أي سلوك تنقّل داخل التطبيق نفسه.
void configureUrlStrategy() => usePathUrlStrategy();
