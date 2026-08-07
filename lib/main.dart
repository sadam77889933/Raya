import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/supervisor_dashboard_screen.dart';
import 'core/services/update_checker_service.dart';
import 'core/widgets/update_dialog.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
}

class QuranCircleReportApp extends ConsumerWidget {
  const QuranCircleReportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'دفتر الحلقة',
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
        // نفحص التحديث بعد اكتمال البناء الأول للشاشة
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());

        final user = authState.user;
        if (user != null && user.isSupervisor) {
          return const SupervisorDashboardScreen();
        }
        return Router.withConfig(config: appRouter);
    }
  }
}