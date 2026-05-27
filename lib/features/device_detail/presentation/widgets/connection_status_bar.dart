import 'package:flutter/material.dart';

import '../../../ble/domain/entities/ble_connection_status.dart';

/// A color-coded status pill that reflects the current BLE connection state.
///
/// Placed at the top of the DeviceDetailPage, always visible.
class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({
    super.key,
    required this.status,
    required this.deviceName,
    this.reconnectAttempt,
    this.maxReached = false,
    this.onReconnect,
    this.onDisconnect,
  });

  final BleConnectionStatus status;
  final String deviceName;
  final int? reconnectAttempt;
  final bool maxReached;
  final VoidCallback? onReconnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.border.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatusDot(color: colors.dot, isAnimating: _shouldPulse(status)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (reconnectAttempt != null)
                  Text(
                    maxReached
                        ? 'Max reconnect attempts reached'
                        : 'Attempt $reconnectAttempt of ${3}…',
                    style: TextStyle(
                      color: colors.text.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (maxReached && onReconnect != null)
            _ActionButton(
              label: 'Retry',
              color: colors.dot,
              onTap: onReconnect!,
            ),
          if (status == BleConnectionStatus.ready && onDisconnect != null)
            _ActionButton(
              label: 'Disconnect',
              color: const Color(0xFFEF5350),
              onTap: onDisconnect!,
            ),
        ],
      ),
    );
  }

  bool _shouldPulse(BleConnectionStatus s) =>
      s == BleConnectionStatus.connecting ||
      s == BleConnectionStatus.discovering;

  _StatusColors _statusColors(BleConnectionStatus s) {
    return switch (s) {
      BleConnectionStatus.connecting => const _StatusColors(
          background: Color(0xFF1A1A2E),
          border: Color(0xFFFFA726),
          dot: Color(0xFFFFA726),
          text: Color(0xFFFFA726),
        ),
      BleConnectionStatus.discovering => const _StatusColors(
          background: Color(0xFF1A1A2E),
          border: Color(0xFF42A5F5),
          dot: Color(0xFF42A5F5),
          text: Color(0xFF42A5F5),
        ),
      BleConnectionStatus.connected => const _StatusColors(
          background: Color(0xFF1A1A2E),
          border: Color(0xFF29B6F6),
          dot: Color(0xFF29B6F6),
          text: Color(0xFF29B6F6),
        ),
      BleConnectionStatus.ready => const _StatusColors(
          background: Color(0xFF0D1B2A),
          border: Color(0xFF26C6DA),
          dot: Color(0xFF26C6DA),
          text: Color(0xFF26C6DA),
        ),
      BleConnectionStatus.disconnecting => const _StatusColors(
          background: Color(0xFF1A1A2E),
          border: Color(0xFFFF7043),
          dot: Color(0xFFFF7043),
          text: Color(0xFFFF7043),
        ),
      BleConnectionStatus.disconnected => const _StatusColors(
          background: Color(0xFF12121F),
          border: Color(0xFF546E7A),
          dot: Color(0xFF546E7A),
          text: Color(0xFF546E7A),
        ),
      BleConnectionStatus.error => const _StatusColors(
          background: Color(0xFF2D1B1B),
          border: Color(0xFFEF5350),
          dot: Color(0xFFEF5350),
          text: Color(0xFFEF5350),
        ),
    };
  }
}

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.border,
    required this.dot,
    required this.text,
  });
  final Color background;
  final Color border;
  final Color dot;
  final Color text;
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.isAnimating});
  final Color color;
  final bool isAnimating;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isAnimating) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.isAnimating != old.isAnimating) {
      widget.isAnimating ? _ctrl.repeat(reverse: true) : _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
