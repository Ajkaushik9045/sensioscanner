import '../../../ble/domain/entities/ble_connection_status.dart';
import '../../../ble/domain/repositories/i_ble_repository.dart';

class ConnectToDeviceUseCase {
  final IBleRepository _repository;

  ConnectToDeviceUseCase(this._repository);

  Stream<BleConnectionStatus> call(String deviceId) {
    return _repository.connectToDevice(deviceId);
  }
}
