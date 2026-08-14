import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/report_form/presentation/screens/circle_info_screen.dart';
import '../../features/report_form/presentation/screens/students_table_screen.dart';
import '../../features/report_form/presentation/screens/report_preview_screen.dart';
import '../../features/pdf_export/presentation/screens/pdf_export_screen.dart';
import '../../features/roster/presentation/screens/roster_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/mosques/presentation/screens/manage_mosques_screen.dart';
class AppRoutes {
  AppRoutes._();
  static const String home = '/';
  static const String login = '/login';
  static const String roster = '/roster';
  static const String circleInfo = '/circle-info';
  static const String studentsTable = '/students-table';
  static const String reportPreview = '/report-preview';
  static const String pdfExport = '/pdf-export';
  static const String manageMosques = '/manage-mosques';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.manageMosques,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const ManageMosquesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const HomeScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.roster,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const RosterScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.circleInfo,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const CircleInfoScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.studentsTable,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const StudentsTableScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.reportPreview,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const ReportPreviewScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.pdfExport,
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const PdfExportScreen(),
      ),
    ),
  ],
  errorPageBuilder: (context, state) => _buildPage(
    state: state,
    child: Scaffold(
      body: Center(
        child: Text(
          'الصفحة غير موجودة',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    ),
  ),
);

CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(-1.0, 0.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}