import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Phase 0 placeholder page — replaced in Phase 1 with the real scanner UI.
///
/// Displays the app brand identity and confirms the theme + routing are wired.
class ScannerPlaceholderPage extends StatelessWidget {
  const ScannerPlaceholderPage({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withAlpha(220),
              cs.secondary.withAlpha(200),
              cs.primaryContainer,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon ────────────────────────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(80),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── App name ────────────────────────────────────────────────
                  Text(
                    'SensioScanner',
                    style: tt.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Subtitle ────────────────────────────────────────────────
                  Text(
                    subtitle ?? 'BLE Vitals Scanner',
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── Phase badge ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: AppRadius.button,
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Phase 0 — Foundation ✓',
                      style: tt.labelLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Status chips ────────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _StatusChip(label: 'DI ✓', icon: Icons.hub_rounded),
                      _StatusChip(
                        label: 'Router ✓',
                        icon: Icons.route_rounded,
                      ),
                      _StatusChip(
                        label: 'Theme ✓',
                        icon: Icons.palette_rounded,
                      ),
                      _StatusChip(
                        label: 'Permissions ✓',
                        icon: Icons.security_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: AppRadius.chip,
        border: Border.all(
          color: Colors.white.withAlpha(50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
