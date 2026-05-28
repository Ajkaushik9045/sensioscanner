import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/permission_service.dart';
import '../../../ble/domain/entities/ble_device.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';

/// Phase 2: Scanner Page
class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScannerBloc>()..add(const RequestPermissionsAndScanEvent()),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  final TextEditingController _nameController = TextEditingController();
  String _nameFilter = '';
  double _rssiThreshold = -100.0;
  bool _showFilters = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildFilterPanel() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: !_showFilters
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B2D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF26C6DA).withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Name Filter ---
                  Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF26C6DA), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Filter by Name',
                        style: TextStyle(
                          color: Color(0xFF26C6DA),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _nameController,
                      onChanged: (val) {
                        setState(() {
                          _nameFilter = val.trim();
                        });
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. SensioVital',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF16324F),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _nameFilter.isEmpty
                            ? null
                            : IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white70),
                                onPressed: () {
                                  setState(() {
                                    _nameController.clear();
                                    _nameFilter = '';
                                  });
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- RSSI Filter ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_rounded, color: Color(0xFF26C6DA), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'RSSI Threshold',
                            style: TextStyle(
                              color: Color(0xFF26C6DA),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '≥ ${_rssiThreshold.round()} dBm',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF26C6DA),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF26C6DA),
                      overlayColor: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                      valueIndicatorColor: const Color(0xFF16324F),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _rssiThreshold,
                      min: -100,
                      max: -30,
                      divisions: 70,
                      label: '${_rssiThreshold.round()} dBm',
                      onChanged: (val) {
                        setState(() {
                          _rssiThreshold = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF1A3A5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SensioScanner', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Discover nearby BLE devices',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
              color: _showFilters ? const Color(0xFF26C6DA) : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: 'Filter List',
          ),
          BlocBuilder<ScannerBloc, ScannerState>(
            builder: (context, state) {
              if (state is ScannerScanning) {
                return IconButton(
                  icon: const Icon(Icons.stop_rounded),
                  onPressed: () => context.read<ScannerBloc>().add(const StopScanEvent()),
                  tooltip: 'Stop Scan',
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () =>
                    context.read<ScannerBloc>().add(const RequestPermissionsAndScanEvent()),
                tooltip: 'Scan',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterPanel(),
          Expanded(
            child: BlocBuilder<ScannerBloc, ScannerState>(
              builder: (context, state) {
                if (state is ScannerInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ScannerPermissionRequired) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bluetooth_disabled_rounded, size: 64, color: Colors.white38),
                          const SizedBox(height: 16),
                          const Text(
                            'Bluetooth permissions are required to scan for nearby devices.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () =>
                                context.read<ScannerBloc>().add(const RequestPermissionsAndScanEvent()),
                            child: const Text('Grant Permissions'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is ScannerError) {
                  final isBluetoothOff = state.message.contains('Bluetooth is turned off');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFEF5350)),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFEF5350)),
                          ),
                          const SizedBox(height: 24),
                          if (isBluetoothOff) ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.bluetooth_rounded),
                              label: const Text('Turn on Bluetooth'),
                              onPressed: () async {
                                final success = await sl<PermissionService>().enableBluetooth();
                                if (success && context.mounted) {
                                  // Wait for the adapter to transition to STATE_ON before retrying scan
                                  await Future.delayed(const Duration(milliseconds: 1500));
                                  if (context.mounted) {
                                    context.read<ScannerBloc>().add(const RequestPermissionsAndScanEvent());
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26C6DA),
                                foregroundColor: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton(
                            onPressed: () =>
                                context.read<ScannerBloc>().add(const RequestPermissionsAndScanEvent()),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var devices = _getDevices(state);
                final totalDevicesCount = devices.length;

                // Apply name filter
                if (_nameFilter.isNotEmpty) {
                  devices = devices
                      .where((d) => d.name.toLowerCase().contains(_nameFilter.toLowerCase()))
                      .toList();
                }

                // Apply RSSI filter
                devices = devices
                    .where((d) => d.rssi >= _rssiThreshold)
                    .toList();

                final isScanning = state is ScannerScanning;
                final hasFilters = _nameFilter.isNotEmpty || _rssiThreshold > -100;

                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isScanning && !hasFilters) ...[
                          _PulseAnimation(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF26C6DA).withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.bluetooth_searching_rounded, size: 64, color: Color(0xFF26C6DA)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('Scanning for devices...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ] else ...[
                          Icon(
                            hasFilters ? Icons.filter_alt_off_rounded : Icons.devices_rounded,
                            size: 64,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasFilters
                                ? 'No devices match your filters.\n($totalDevicesCount nearby)'
                                : 'No devices found.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    if (isScanning) const LinearProgressIndicator(color: Color(0xFF26C6DA), backgroundColor: Colors.transparent),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DeviceTile(device: device),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<BleDevice> _getDevices(ScannerState state) {
    if (state is ScannerScanning) return state.devices;
    if (state is ScannerStopped) return state.devices;
    return const [];
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final BleDevice device;

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName(device);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16324F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: device.isConnectable
              ? () {
                  context.push(
                    AppRoutes.deviceDetail.replaceFirst(':deviceId', Uri.encodeComponent(device.id)),
                    extra: device.name,
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF102A43)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Icon(
                    Icons.bluetooth_rounded,
                    size: 28,
                    color: device.isConnectable ? const Color(0xFF26C6DA) : Colors.white38,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.id,
                        style: const TextStyle(fontSize: 12, color: Colors.white54, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${device.rssi} dBm',
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    _SignalBars(strength: device.signalStrength),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayName(BleDevice device) {

  // Real device name available
  if (device.name.trim().isNotEmpty) {
    return device.name;
  }

  // Manufacturer data fallback
  if (device.manufacturerData.isNotEmpty) {

    final firstEntry = device.manufacturerData.entries.first;

    final companyId = firstEntry.key;
    final bytes = firstEntry.value;

    final hexPreview = bytes
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');

    return 'BLE Device ($companyId • $hexPreview)';
  }

  // // Service UUID fallback
  // if (device.serviceUuids.isNotEmpty) {
  //   return 'BLE Service Device';
  // }

  // Final fallback
  return 'Unknown BLE Device';
}
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.strength});
  final SignalStrength strength;

  @override
  Widget build(BuildContext context) {
    final bars = switch (strength) {
      SignalStrength.excellent => 4,
      SignalStrength.good => 3,
      SignalStrength.fair => 2,
      SignalStrength.poor => 1,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final active = index < bars;
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: 4,
          height: 6.0 + (index * 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF26C6DA) : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation({required this.child});
  final Widget child;

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF26C6DA).withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}
