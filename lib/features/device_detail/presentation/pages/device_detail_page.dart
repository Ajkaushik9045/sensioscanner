import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../ble/domain/entities/ble_connection_status.dart';
import '../bloc/device_detail_bloc.dart';
import '../bloc/device_detail_event.dart';
import '../bloc/device_detail_state.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/services_accordion.dart';
import '../widgets/value_display.dart';
import '../widgets/vitals_dashboard.dart';

class DeviceDetailPage extends StatelessWidget {
  const DeviceDetailPage({
    super.key,
    required this.deviceId,
    this.deviceName,
  });

  final String deviceId;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DeviceDetailBloc>()
        ..add(ConnectToDeviceEvent(
          deviceId: deviceId,
          deviceName: deviceName ?? 'Unknown Device',
        )),
      child: _DeviceDetailView(deviceId: deviceId, deviceName: deviceName ?? 'Unknown Device'),
    );
  }
}

class _DeviceDetailView extends StatelessWidget {
  const _DeviceDetailView({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeviceDetailBloc, DeviceDetailState>(
      listenWhen: (previous, current) => current is DetailDisconnected || current is DetailError,
      listener: (context, state) {
        if (state is DetailDisconnected) {
          if (context.canPop()) context.pop();
        } else if (state is DetailError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFFEF5350),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(deviceName),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                // If connected, dispatch disconnect which will eventually pop.
                // Otherwise just pop.
                if (state is DetailConnected || state is DetailConnecting || state is DetailConnectionLost) {
                  context.read<DeviceDetailBloc>().add(const DisconnectDeviceEvent());
                } else {
                  if (context.canPop()) context.pop();
                }
              },
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DeviceDetailState state) {
    return Column(
      children: [
        // ── Top Connection Status Bar ─────────────────────────────────────────
        if (state is DetailConnecting)
          ConnectionStatusBar(
            status: state.isDiscovering ? BleConnectionStatus.discovering : BleConnectionStatus.connecting,
            deviceName: state.deviceName,
            onDisconnect: () => context.read<DeviceDetailBloc>().add(const DisconnectDeviceEvent()),
          )
        else if (state is DetailConnected)
          ConnectionStatusBar(
            status: state.connectionStatus,
            deviceName: state.deviceName,
            onDisconnect: () => context.read<DeviceDetailBloc>().add(const DisconnectDeviceEvent()),
          )
        else if (state is DetailConnectionLost)
          ConnectionStatusBar(
            status: BleConnectionStatus.error,
            deviceName: state.deviceName,
            reconnectAttempt: state.reconnectAttempt,
            maxReached: state.maxReached,
            onReconnect: () => context.read<DeviceDetailBloc>().add(const ManualReconnectEvent()),
            onDisconnect: () => context.read<DeviceDetailBloc>().add(const DisconnectDeviceEvent()),
          )
        else if (state is DetailDisconnecting)
          ConnectionStatusBar(
            status: BleConnectionStatus.disconnecting,
            deviceName: state.deviceName,
          )
        else if (state is DetailDisconnected)
          ConnectionStatusBar(
            status: BleConnectionStatus.disconnected,
            deviceName: deviceName,
          ),

        // ── Main Content Area ────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (state is DetailConnected) ...[
                  // ── Error Snackbar equivalent (inline) ──────────────────────
                  if (state.subscriptionError != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D1B1B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.subscriptionError!,
                              style: const TextStyle(color: Color(0xFFEF5350), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Multi-Stream Dashboard (SensioVital) ────────────────────
                  if (state.isMultiStreaming && state.hasMultiData)
                    VitalsDashboard(
                      latestValues: state.latestValues,
                      histories: state.histories,
                    ),

                  // ── Single-Stream Value Display (Legacy) ────────────────────
                  if (!state.isMultiStreaming && state.isStreaming && state.latestValue != null)
                    ValueDisplay(
                      latestValue: state.latestValue!,
                      history: state.history,
                    ),

                  // ── Services Accordion ──────────────────────────────────────
                  const SizedBox(height: 8),
                  ServicesAccordion(
                    deviceId: state.deviceId,
                    services: state.services,
                    activeCharacteristicUuids: state.isMultiStreaming
                        ? state.activeCharacteristics.keys.toSet()
                        : {if (state.activeCharacteristic != null) state.activeCharacteristic!.uuid},
                    onSubscribe: (qc, bc) {
                      context.read<DeviceDetailBloc>().add(
                            SubscribeToCharacteristicEvent(
                              qualifiedCharacteristic: qc,
                              bleCharacteristic: bc,
                            ),
                          );
                    },
                    onUnsubscribe: (charUuid) {
                      context.read<DeviceDetailBloc>().add(
                            UnsubscribeFromCharacteristicEvent(
                              characteristicUuid: charUuid,
                            ),
                          );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
