import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer portrait orientation during initial launch.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent system bars to let the gradient bleed through.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Wire up the service locator before the widget tree is built.
  await configureDependencies();

  runApp(const SensioScannerApp());
}

/// Root application widget.
///
/// Uses [MaterialApp.router] so GoRouter owns the navigation stack.
/// Theme tokens are defined in [AppTheme]; DI is set up in [configureDependencies].
class SensioScannerApp extends StatelessWidget {
  const SensioScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SensioScanner',
      debugShowCheckedModeBanner: false,

      // ── Theme ──────────────────────────────────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // ── Routing ────────────────────────────────────────────────────────────
      routerConfig: appRouter,
    );
  }
}
