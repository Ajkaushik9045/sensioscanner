import '../../../../core/di/injection.dart';
import 'device_detail_bloc.dart';
import 'device_detail_state.dart';

/// A registry that manages and caches [DeviceDetailBloc] instances per device.
///
/// This allows the BLE connection to persist in the background when the user
/// navigates back to the scanner or history pages. When the user re-enters
/// a device detail page, the same BLoC (and GATT connection state) is restored.
final class DeviceDetailBlocRegistry {
  final Map<String, DeviceDetailBloc> _blocs = {};

  /// Retrieves an existing [DeviceDetailBloc] or creates a new one.
  ///
  /// If the existing BLoC is closed or has transitioned to a disconnected state,
  /// it is discarded and a new one is created.
  DeviceDetailBloc getOrCreate(String deviceId) {
    if (_blocs.containsKey(deviceId)) {
      final existing = _blocs[deviceId]!;
      if (existing.isClosed || existing.state is DetailDisconnected) {
        _blocs.remove(deviceId);
      } else {
        return existing;
      }
    }

    // Create a new factory instance from the service locator.
    final bloc = sl<DeviceDetailBloc>();
    _blocs[deviceId] = bloc;
    return bloc;
  }

  /// Removes and disposes (closes) the BLoC associated with the given [deviceId].
  Future<void> remove(String deviceId) async {
    final bloc = _blocs.remove(deviceId);
    if (bloc != null && !bloc.isClosed) {
      await bloc.close();
    }
  }

  /// Disposes and closes all active BLoCs in the registry.
  Future<void> disposeAll() async {
    for (final bloc in _blocs.values) {
      if (!bloc.isClosed) {
        await bloc.close();
      }
    }
    _blocs.clear();
  }
}
