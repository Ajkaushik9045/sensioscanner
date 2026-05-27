import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide CharacteristicValue, ScanFailure, Unit;

import '../../../ble/domain/entities/ble_characteristic.dart';
import '../../../ble/domain/entities/ble_service.dart';
import 'characteristic_panel.dart';

/// Collapsible accordion that lists discovered GATT services and their
/// characteristics. Each service tile expands to show a [CharacteristicPanel]
/// for each characteristic.
class ServicesAccordion extends StatefulWidget {
  const ServicesAccordion({
    super.key,
    required this.services,
    required this.deviceId,
    this.activeCharacteristicUuid,
    this.onSubscribe,
    this.onUnsubscribe,
  });

  final List<BleService> services;
  final String deviceId;
  final String? activeCharacteristicUuid;
  final void Function(QualifiedCharacteristic, BleCharacteristic)? onSubscribe;
  final VoidCallback? onUnsubscribe;

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
          activeCharacteristicUuid: widget.activeCharacteristicUuid,
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
    this.activeCharacteristicUuid,
    this.onSubscribe,
    this.onUnsubscribe,
  });

  final BleService service;
  final String deviceId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? activeCharacteristicUuid;
  final void Function(QualifiedCharacteristic, BleCharacteristic)? onSubscribe;
  final VoidCallback? onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final hasSubscribable = service.subscribableCharacteristics.isNotEmpty;

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
                        Icons.settings_input_antenna_rounded,
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
                          Text(
                            _shortUuid(service.uuid),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
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
                    final isActive = char.uuid == activeCharacteristicUuid;
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
                      onUnsubscribe: isActive ? onUnsubscribe : null,
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

  /// Returns just the last 8 chars of UUID for compact display (e.g. "0000180D").
  String _shortUuid(String uuid) {
    final stripped = uuid.replaceAll('-', '');
    return stripped.length > 8
        ? '…${stripped.substring(stripped.length - 8)}'
        : stripped;
  }
}
