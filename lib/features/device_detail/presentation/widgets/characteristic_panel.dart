import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide CharacteristicValue, ScanFailure, Unit;

import '../../../../core/services/ble_uuid_names.dart';
import '../../../ble/domain/entities/ble_characteristic.dart';

/// Displays a single GATT characteristic with its property badges and
/// a subscribe/unsubscribe action button.
///
/// Shows a human-readable name when the characteristic UUID is recognised
/// (e.g. "Heart Rate Measurement" instead of "0x00002A37").
class CharacteristicPanel extends StatelessWidget {
  const CharacteristicPanel({
    super.key,
    required this.characteristic,
    required this.qualifiedCharacteristic,
    required this.isActive,
    this.onSubscribe,
    this.onUnsubscribe,
  });

  final BleCharacteristic characteristic;
  final QualifiedCharacteristic qualifiedCharacteristic;
  final bool isActive;
  final VoidCallback? onSubscribe;
  final void Function(String characteristicUuid)? onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final charName = getCharacteristicName(characteristic.uuid);
    final isKnown = isKnownCharacteristic(characteristic.uuid);
    final description = getCharacteristicDescription(characteristic.uuid);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0D2137)
            : const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? const Color(0xFF26C6DA).withOpacity(0.7)
              : const Color(0xFF1E3A5F).withOpacity(0.5),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + UUID + properties ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Human-readable name ──────────────────────────────────
                    Text(
                      charName,
                      style: TextStyle(
                        color: isKnown ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // ── UUID subtitle ─────────────────────────────────────────
                    Text(
                      shortUuid(characteristic.uuid),
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                    // ── Description tooltip ───────────────────────────────────
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: characteristic.properties
                          .map(_propertyBadge)
                          .toList(),
                    ),
                  ],
                ),
              ),

              // ── Subscribe / Unsubscribe button ─────────────────────────────
              if (characteristic.canSubscribe) ...[
                const SizedBox(width: 8),
                _SubscribeButton(
                  isActive: isActive,
                  onSubscribe: onSubscribe,
                  onUnsubscribe: isActive && onUnsubscribe != null
                      ? () => onUnsubscribe!(characteristic.uuid)
                      : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _propertyBadge(CharacteristicProperty prop) {
    final (label, color) = switch (prop) {
      CharacteristicProperty.read => ('READ', const Color(0xFF42A5F5)),
      CharacteristicProperty.write => ('WRITE', const Color(0xFFAB47BC)),
      CharacteristicProperty.writeWithoutResponse =>
        ('WRITE NR', const Color(0xFF7E57C2)),
      CharacteristicProperty.notify => ('NOTIFY', const Color(0xFF26C6DA)),
      CharacteristicProperty.indicate => ('INDICATE', const Color(0xFF00E5FF)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    required this.isActive,
    this.onSubscribe,
    this.onUnsubscribe,
  });

  final bool isActive;
  final VoidCallback? onSubscribe;
  final VoidCallback? onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final isEnabled = isActive ? onUnsubscribe != null : onSubscribe != null;
    final color = isActive ? const Color(0xFFEF5350) : const Color(0xFF26C6DA);
    final label = isActive ? 'Stop' : 'Subscribe';
    final icon = isActive ? Icons.stop_rounded : Icons.notifications_active_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? (isActive ? onUnsubscribe : onSubscribe) : null,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
