import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide CharacteristicValue, ScanFailure, Unit;

import '../../../../core/services/ble_uuid_names.dart';
import '../../../ble/domain/entities/ble_characteristic.dart';
import '../../../ble/domain/entities/ble_service.dart';
import 'characteristic_panel.dart';

/// Collapsible accordion that lists discovered GATT services and their
/// characteristics. Each service tile expands to show a [CharacteristicPanel]
/// for each characteristic.
///
/// Services and characteristics now display human-readable names when the
/// UUID is recognised (e.g. "Heart Rate Service" instead of "…0000180D").
class ServicesAccordion extends StatefulWidget {
  const ServicesAccordion({
    super.key,
    required this.services,
    required this.deviceId,
    required this.activeCharacteristicUuids,
    this.onSubscribe,
    this.onUnsubscribe,
  });

  final List<BleService> services;
  final String deviceId;
  final Set<String> activeCharacteristicUuids;
  final void Function(QualifiedCharacteristic, BleCharacteristic)? onSubscribe;
  final void Function(String characteristicUuid)? onUnsubscribe;

  @override
  State<ServicesAccordion> createState() => _ServicesAccordionState();
}

class _ServicesAccordionState extends State<ServicesAccordion> {
  // Track which services are expanded. Default: expand the first one.
  final Set<String> _expandedUuids = {};

  @override
  void initState() {
    super.initState();
    if (widget.services.isNotEmpty) {
      _expandedUuids.add(widget.services.first.uuid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No services found',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.services.length,
      itemBuilder: (context, index) {
        final service = widget.services[index];
        return _ServiceTile(
          service: service,
          deviceId: widget.deviceId,
          isExpanded: _expandedUuids.contains(service.uuid),
          activeCharacteristicUuids: widget.activeCharacteristicUuids,
          onToggle: () => setState(() {
            if (_expandedUuids.contains(service.uuid)) {
              _expandedUuids.remove(service.uuid);
            } else {
              _expandedUuids.add(service.uuid);
            }
          }),
          onSubscribe: widget.onSubscribe,
          onUnsubscribe: widget.onUnsubscribe,
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.deviceId,
    required this.isExpanded,
    required this.onToggle,
    required this.activeCharacteristicUuids,
    this.onSubscribe,
    this.onUnsubscribe,
  });

  final BleService service;
  final String deviceId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Set<String> activeCharacteristicUuids;
  final void Function(QualifiedCharacteristic, BleCharacteristic)? onSubscribe;
  final void Function(String characteristicUuid)? onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final hasSubscribable = service.subscribableCharacteristics.isNotEmpty;
    final serviceName = getServiceName(service.uuid);
    final isKnown = isKnownService(service.uuid);
    final serviceIcon = _serviceIcon(service.uuid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSubscribable
              ? const Color(0xFF26C6DA).withOpacity(0.3)
              : const Color(0xFF1E3A5F),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // ── Service header ───────────────────────────────────────────────
            InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A5C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        serviceIcon,
                        size: 18,
                        color: hasSubscribable
                            ? const Color(0xFF26C6DA)
                            : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Human-readable name ─────────────────────────────
                          Text(
                            serviceName,
                            style: TextStyle(
                              color: isKnown ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // ── UUID subtitle ───────────────────────────────────
                          Text(
                            shortUuid(service.uuid),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${service.characteristics.length} characteristic${service.characteristics.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Characteristics list ─────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  const Divider(color: Color(0xFF1E3A5F), height: 1),
                  ...service.characteristics.map((char) {
                    final isActive = activeCharacteristicUuids.contains(char.uuid);
                    final qc = QualifiedCharacteristic(
                      characteristicId: Uuid.parse(char.uuid),
                      serviceId: Uuid.parse(char.serviceUuid),
                      deviceId: deviceId,
                    );
                    return CharacteristicPanel(
                      characteristic: char,
                      qualifiedCharacteristic: qc,
                      isActive: isActive,
                      onSubscribe: onSubscribe != null
                          ? () => onSubscribe!(qc, char)
                          : null,
                      onUnsubscribe: onUnsubscribe,
                    );
                  }),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a context-appropriate icon based on the service UUID.
  IconData _serviceIcon(String uuid) {
    final norm = uuid.toLowerCase();
    if (norm.contains('180d')) return Icons.favorite_rounded;
    if (norm.contains('180f')) return Icons.battery_charging_full_rounded;
    if (norm.contains('180a')) return Icons.info_outline_rounded;
    if (norm.contains('1800')) return Icons.bluetooth_rounded;
    if (norm.contains('1801')) return Icons.settings_rounded;
    // SensioVital custom vitals service
    if (norm.startsWith('12345678')) return Icons.monitor_heart_rounded;
    return Icons.settings_input_antenna_rounded;
  }
}
