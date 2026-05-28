import 'package:flutter/material.dart';
import '../../../ble/domain/entities/ble_device.dart';

class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.strength});
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
