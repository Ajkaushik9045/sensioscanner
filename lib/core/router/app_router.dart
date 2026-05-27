import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/device_detail/presentation/pages/device_detail_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/scanner/presentation/pages/scanner_page.dart';
import 'main_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route name constants
// Centralised here so every navigation call uses typed names, not magic strings.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppRoutes {
  static const String scanner = '/';
  static const String history = '/history';
  static const String deviceDetail = '/device/:deviceId';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Application-level [GoRouter] configuration.
///
/// Phase 0: Skeleton with the scanner (home) route only.
/// Phase 1+: Add device detail route, permission gate, transition animations.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  debugLogDiagnostics: true,
  initialLocation: AppRoutes.scanner,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainLayout(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.scanner,
              name: 'scanner',
              builder: (context, state) => const ScannerPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.history,
              name: 'history',
              builder: (context, state) => const HistoryPage(),
            ),
          ],
        ),
      ],
    ),
    // ── Device Detail ─────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.deviceDetail,
      name: 'deviceDetail',
      // We push the detail page over the entire shell route so it hides the bottom bar
      parentNavigatorKey: _rootNavigatorKey, 
      builder: (context, state) {
        final deviceId = state.pathParameters['deviceId'] ?? '';
        final deviceName = state.extra as String?;
        final decodedDeviceId = Uri.decodeComponent(deviceId);
        return DeviceDetailPage(
          deviceId: decodedDeviceId,
          deviceName: deviceName,
        );
      },
    ),
  ],
);
