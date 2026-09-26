import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/router/app_router.dart';
import 'core/router/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/supervisor_dashboard_screen.dart';
import 'core/services/update_checker_service.dart';
import 'core/widgets/update_dialog.dart';
import 'features/auth/presentation/screens/mosque_supervisor_dashboard_screen.dart';
import 'features/notifications/data/scheduled_notification_service.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';

/// مفتاح تنقّل جذري — يسمح بفتح شاشة الإشعارات من خارج شجرة الودجت (عند
/// الضغط على إشعار Push نظامي)، بصرف النظر عن أي شاشة مفتوحة حالياً تحتها
/// (لوحة المشرفة العامة/مشرفة المسجد/الشاشة الرئيسية للمعلمة).
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: QuranCircleReportApp(),
    ),
  );

  // فتح شاشة الإشعارات تلقائياً عند الضغط على إشعار Push نظامي — على
  // أندرويد/iOS فقط (firebase_messaging يدعمها، لكن الويب يعتمد بدلاً من
  // ذلك على firebase-messaging-sw.js الذي يكتفي بفتح/تركيز نافذة التطبيق
  // على الصفحة الرئيسية، دون معرفة مسبقة بأي صفحة داخلية).
  if (!kIsWeb) {
    _openNotificationsIfLaunchedFromPush();
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    });
  }
}

/// يغطي حالة: التطبيق كان مغلقاً تماماً وفُتح بالضغط على الإشعار مباشرة.
Future<void> _openNotificationsIfLaunchedFromPush() async {
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  });
}

class QuranCircleReportApp extends ConsumerWidget {
  const QuranCircleReportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'رعاية',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}
/// بوابة تحقق: توجّه المستخدم لتسجيل الدخول أو للتطبيق حسب حالته
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _updateChecked = false;

  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;

    final updateInfo = await UpdateCheckerService().checkForUpdate();
    if (!mounted) return;
    await UpdateDialog.showIfNeeded(context, updateInfo);

    // فحص الرسائل المجدولة بصمت (لا نوقف أي شيء لو فشل)
    // فحص الرسائل المجدولة بصمت (لا نوقف أي شيء لو فشل)
    debugPrint('بدء فحص الرسائل المجدولة...');
    await ScheduledNotificationService().checkAndSendDueNotifications();
    debugPrint('انتهى فحص الرسائل المجدولة');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.signedOut:
      case AuthStatus.error:
        return const LoginScreen();
      case AuthStatus.signedIn:
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());

        final user = authState.user;
        if (user != null && user.isSupervisor) {
          return const SupervisorDashboardScreen();
        }
        if (user != null && user.isMosqueSupervisor) {
          return const MosqueSupervisorDashboardScreen();
        }
        return Router.withConfig(config: appRouter);
    }
  }
}
