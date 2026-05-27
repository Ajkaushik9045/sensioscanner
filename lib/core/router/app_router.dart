import 'package:go_router/go_router.dart';

import '../../features/scanner/presentation/pages/scanner_placeholder_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route name constants
// Centralised here so every navigation call uses typed names, not magic strings.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppRoutes {
  static const String scanner = '/';
  static const String deviceDetail = '/device/:deviceId';
}

/// Application-level [GoRouter] configuration.
///
/// Phase 0: Skeleton with the scanner (home) route only.
/// Phase 1+: Add device detail route, permission gate, transition animations.
final GoRouter appRouter = GoRouter(
  debugLogDiagnostics: true,
  initialLocation: AppRoutes.scanner,
  routes: [
    // ── Scanner / Home ────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.scanner,
      name: 'scanner',
      builder: (context, state) => const ScannerPlaceholderPage(),
    ),

    // ── Device Detail ─────────────────────────────────────────────────────────
    // Placeholder — will be replaced in Phase 1 with the real DeviceDetailPage.
    GoRoute(
      path: AppRoutes.deviceDetail,
      name: 'deviceDetail',
      builder: (context, state) {
        final deviceId = state.pathParameters['deviceId'] ?? '';
        return ScannerPlaceholderPage(
          subtitle: 'Device: $deviceId',
        );
      },
    ),
  ],
);
