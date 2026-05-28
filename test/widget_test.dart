import 'package:dartz/dartz.dart' hide Unit;
import 'package:dartz/dartz.dart' as dartz show Unit;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' hide CharacteristicValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensioscanner/core/di/injection.dart';
import 'package:sensioscanner/core/error/failures.dart';
import 'package:sensioscanner/core/services/permission_service.dart';
import 'package:sensioscanner/features/ble/domain/entities/ble_connection_status.dart';
import 'package:sensioscanner/features/ble/domain/entities/ble_device.dart';
import 'package:sensioscanner/features/ble/domain/entities/ble_service.dart';
import 'package:sensioscanner/features/ble/domain/entities/characteristic_value.dart';
import 'package:sensioscanner/features/ble/domain/repositories/i_ble_repository.dart';
import 'package:sensioscanner/features/scanner/domain/usecases/scan_devices_use_case.dart';
import 'package:sensioscanner/features/scanner/domain/usecases/stop_scan_use_case.dart';
import 'package:sensioscanner/features/scanner/presentation/bloc/scanner_bloc.dart';
import 'package:sensioscanner/main.dart';

class FakeBleRepository implements IBleRepository {
  @override
  Stream<Either<BleFailure, List<BleDevice>>> scanDevices({List<Uuid> withServices = const []}) {
    return const Stream.empty();
  }

  @override
  Future<void> stopScan() async {}

  @override
  Stream<BleConnectionStatus> connectToDevice(String deviceId) {
    return const Stream.empty();
  }

  @override
  Future<Either<BleFailure, List<BleService>>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<BleFailure, int>> requestMtu(String deviceId, int mtu) async {
    return const Right(23);
  }

  @override
  Stream<Either<BleFailure, CharacteristicValue>> subscribeToCharacteristic(
    QualifiedCharacteristic characteristic,
  ) {
    return const Stream.empty();
  }

  @override
  Future<Either<BleFailure, CharacteristicValue>> readCharacteristic(
    QualifiedCharacteristic characteristic,
  ) async {
    return Right(
      CharacteristicValue(
        characteristicUuid: characteristic.characteristicId.toString(),
        serviceUuid: characteristic.serviceId.toString(),
        deviceId: characteristic.deviceId,
        value: const [],
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<Either<BleFailure, dartz.Unit>> disconnect(String deviceId) async {
    return const Right(unit);
  }

  @override
  Future<void> dispose() async {}
}

class FakePermissionService implements PermissionService {
  const FakePermissionService();

  @override
  Future<Either<PermissionFailure, bool>> requestBlePermissions() async {
    return const Right(true);
  }

  @override
  Future<Either<PermissionFailure, bool>> checkBlePermissions() async {
    return const Right(true);
  }

  @override
  Future<bool> openSettings() async {
    return true;
  }

  @override
  Future<bool> enableBluetooth() async {
    return true;
  }
}

void main() {
  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});

    // Register Fakes for widget tests to avoid platform channel exceptions
    final fakeRepo = FakeBleRepository();
    final fakePermissions = const FakePermissionService();

    sl.registerLazySingleton<IBleRepository>(() => fakeRepo);
    sl.registerLazySingleton<PermissionService>(() => fakePermissions);

    sl.registerLazySingleton<ScanDevicesUseCase>(() => ScanDevicesUseCase(sl<IBleRepository>()));
    sl.registerLazySingleton<StopScanUseCase>(() => StopScanUseCase(sl<IBleRepository>()));

    sl.registerFactory<ScannerBloc>(
      () => ScannerBloc(
        scanDevicesUseCase: sl<ScanDevicesUseCase>(),
        stopScanUseCase: sl<StopScanUseCase>(),
        permissionService: sl<PermissionService>(),
      ),
    );
  });

  testWidgets('SensioScannerApp smoke test — app builds without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SensioScannerApp());
    expect(tester.takeException(), isNull);
  });
}
