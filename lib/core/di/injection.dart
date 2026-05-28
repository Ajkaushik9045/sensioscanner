import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import '../services/permission_service.dart';

// BLE Feature (Shared)
import '../../features/ble/data/repositories/ble_repository_impl.dart';
import '../../features/ble/domain/repositories/i_ble_repository.dart';

// History Feature
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/history/domain/repositories/i_history_repository.dart';
import '../../features/history/domain/usecases/clear_history_use_case.dart';
import '../../features/history/domain/usecases/get_history_use_case.dart';
import '../../features/history/domain/usecases/save_device_to_history_use_case.dart';

// Scanner Feature
import '../../features/scanner/domain/usecases/scan_devices_use_case.dart';
import '../../features/scanner/domain/usecases/stop_scan_use_case.dart';
import '../../features/scanner/presentation/bloc/scanner_bloc.dart';

// Device Detail Feature
import '../../features/device_detail/domain/usecases/connect_to_device_use_case.dart';
import '../../features/device_detail/domain/usecases/disconnect_device_use_case.dart';
import '../../features/device_detail/domain/usecases/discover_services_use_case.dart';
import '../../features/device_detail/domain/usecases/request_mtu_use_case.dart';
import '../../features/device_detail/domain/usecases/read_characteristic_use_case.dart';
import '../../features/device_detail/domain/usecases/subscribe_to_characteristic_use_case.dart';
import '../../features/device_detail/presentation/bloc/device_detail_bloc.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Registers all singletons and factories.
///
/// Call this once before [runApp].
/// Lazy singletons are registered here; heavy objects (BLE, cubits) are
/// only constructed on first access.
Future<void> configureDependencies() async {
  // ── Core: SharedPreferences ────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  // ── Core: BLE driver ───────────────────────────────────────────────────────
  // FlutterReactiveBle is the single source of truth for all BLE operations.
  sl.registerLazySingleton<FlutterReactiveBle>(
    () => FlutterReactiveBle(),
  );

  // ── Core: permissions ──────────────────────────────────────────────────────
  sl.registerLazySingleton<PermissionService>(
    () => const PermissionServiceImpl(),
  );

  // ── Data & Domain Repositories ─────────────────────────────────────────────
  sl.registerLazySingleton<IBleRepository>(
    () => BleRepositoryImpl(sl<FlutterReactiveBle>()),
  );

  sl.registerLazySingleton<IHistoryRepository>(
    () => HistoryRepositoryImpl(sl<SharedPreferences>()),
  );

  // ── Use Cases: Scanner Feature ─────────────────────────────────────────────
  sl.registerLazySingleton<ScanDevicesUseCase>(
    () => ScanDevicesUseCase(sl<IBleRepository>()),
  );
  sl.registerLazySingleton<StopScanUseCase>(
    () => StopScanUseCase(sl<IBleRepository>()),
  );

  // ── Use Cases: Device Detail Feature ───────────────────────────────────────
  sl.registerLazySingleton<ConnectToDeviceUseCase>(
    () => ConnectToDeviceUseCase(sl<IBleRepository>()),
  );
  sl.registerLazySingleton<DisconnectDeviceUseCase>(
    () => DisconnectDeviceUseCase(sl<IBleRepository>()),
  );
  sl.registerLazySingleton<DiscoverServicesUseCase>(
    () => DiscoverServicesUseCase(sl<IBleRepository>()),
  );
  sl.registerLazySingleton<RequestMtuUseCase>(
    () => RequestMtuUseCase(sl<IBleRepository>()),
  );
  sl.registerLazySingleton<SubscribeToCharacteristicUseCase>(
    () => SubscribeToCharacteristicUseCase(sl<IBleRepository>()),
  );
  sl.registerLazySingleton<ReadCharacteristicUseCase>(
    () => ReadCharacteristicUseCase(sl<IBleRepository>()),
  );

  // ── Use Cases: History Feature ─────────────────────────────────────────────
  sl.registerLazySingleton<GetHistoryUseCase>(
    () => GetHistoryUseCase(sl<IHistoryRepository>()),
  );
  sl.registerLazySingleton<ClearHistoryUseCase>(
    () => ClearHistoryUseCase(sl<IHistoryRepository>()),
  );
  sl.registerLazySingleton<SaveDeviceToHistoryUseCase>(
    () => SaveDeviceToHistoryUseCase(sl<IHistoryRepository>()),
  );

  // ── Presentation: BLoCs ────────────────────────────────────────────────────
  sl.registerFactory<ScannerBloc>(
    () => ScannerBloc(
      scanDevicesUseCase: sl<ScanDevicesUseCase>(),
      stopScanUseCase: sl<StopScanUseCase>(),
      permissionService: sl<PermissionService>(),
    ),
  );

  sl.registerFactory<DeviceDetailBloc>(
    () => DeviceDetailBloc(
      connectToDeviceUseCase: sl<ConnectToDeviceUseCase>(),
      disconnectDeviceUseCase: sl<DisconnectDeviceUseCase>(),
      discoverServicesUseCase: sl<DiscoverServicesUseCase>(),
      requestMtuUseCase: sl<RequestMtuUseCase>(),
      subscribeToCharacteristicUseCase: sl<SubscribeToCharacteristicUseCase>(),
      readCharacteristicUseCase: sl<ReadCharacteristicUseCase>(),
      saveDeviceToHistoryUseCase: sl<SaveDeviceToHistoryUseCase>(),
    ),
  );
}
