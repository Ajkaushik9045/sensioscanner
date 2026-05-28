import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../ble/domain/entities/ble_device.dart';
import 'signal_bars.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device});
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
                    SignalBars(strength: device.signalStrength),
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

    // Final fallback
    return 'Unknown BLE Device';
  }
}
