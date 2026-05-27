import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/ble_repository_impl.dart';
import '../../domain/repositories/i_ble_repository.dart';
import '../services/permission_service.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Registers all singletons and factories.
///
/// Call this once before [runApp].
/// Lazy singletons are registered here; heavy objects (BLE, cubits) are
/// only constructed on first access.
Future<void> configureDependencies() async {
  // ── Core: BLE driver ───────────────────────────────────────────────────────

  // FlutterReactiveBle is the single source of truth for all BLE operations.
  // Singleton — one instance per app lifetime.
  sl.registerLazySingleton<FlutterReactiveBle>(
    () => FlutterReactiveBle(),
  );

  // ── Core: permissions ──────────────────────────────────────────────────────

  sl.registerLazySingleton<PermissionService>(
    () => const PermissionServiceImpl(),
  );

  // ── Data: BLE repository ───────────────────────────────────────────────────

  // BLoCs and use-cases depend on the interface (IBleRepository), not the impl.
  // Swapping the impl (e.g. for a mock in tests) requires only this line.
  sl.registerLazySingleton<IBleRepository>(
    () => BleRepositoryImpl(sl<FlutterReactiveBle>()),
  );
}
