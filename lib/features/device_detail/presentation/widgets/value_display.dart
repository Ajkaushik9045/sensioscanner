import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ble/domain/entities/characteristic_value.dart';

/// Displays a live characteristic value in multiple formats.
///
/// Attempts (in order): UTF-8 string → decimal integer → hex fallback.
/// All three formats are shown simultaneously so the user can choose which
/// makes sense for their peripheral.
class ValueDisplay extends StatelessWidget {
  const ValueDisplay({
    super.key,
    required this.latestValue,
    required this.history,
  });

  final CharacteristicValue latestValue;
  final List<CharacteristicValue> history;

  @override
  Widget build(BuildContext context) {
    final numericValues = _extractNumericHistory(history);
    final showSparkline = numericValues.length >= 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1E35), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF26C6DA).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26C6DA).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFF26C6DA),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Value',
                style: TextStyle(
                  color: Color(0xFF26C6DA),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              _TimestampChip(timestamp: latestValue.timestamp),
            ],
          ),
          const SizedBox(height: 14),

          // ── Primary value rows ───────────────────────────────────────────────
          _ValueRow(
            label: 'HEX',
            value: latestValue.hexString,
            color: const Color(0xFF80DEEA),
            isHex: true,
          ),
          const SizedBox(height: 8),
          _ValueRow(
            label: 'DEC',
            value: _toDecimal(latestValue),
            color: const Color(0xFF80CBC4),
          ),
          const SizedBox(height: 8),
          _ValueRow(
            label: 'UTF-8',
            value: _toUtf8(latestValue),
            color: const Color(0xFF90CAF9),
          ),

          // ── Sparkline (bonus — shown when values are numeric) ──────────────
          if (showSparkline) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E3A5F), height: 1),
            const SizedBox(height: 12),
            _SparklineSection(values: numericValues),
          ],
        ],
      ),
    );
  }

  String _toDecimal(CharacteristicValue v) {
    if (v.value.isEmpty) return '—';
    if (v.value.length == 1) return '${v.asByte}';
    final u16 = v.asUint16LE;
    if (u16 != null) return '$u16 (uint16-LE)';
    return v.asInt.toString();
  }

  String _toUtf8(CharacteristicValue v) {
    if (v.value.isEmpty) return '—';
    final s = v.asString;
    // If it equals hex, it was a fallback (non-printable chars)
    if (s == v.hexString) return '(non-printable)';
    return s;
  }

  List<double> _extractNumericHistory(List<CharacteristicValue> history) {
    final result = <double>[];
    for (final v in history) {
      if (v.value.isEmpty) continue;
      double? n;
      if (v.value.length == 1) {
        n = (v.asByte ?? 0).toDouble();
      } else if (v.value.length <= 2) {
        final u = v.asUint16LE;
        if (u != null) n = u.toDouble();
      } else {
        n = v.asInt.toDouble();
      }
      if (n != null) result.add(n);
    }
    return result;
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.color,
    this.isHex = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool isHex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: isHex ? 13 : 14,
              fontFamily: isHex ? 'monospace' : null,
              fontWeight: isHex ? FontWeight.w500 : FontWeight.w600,
              letterSpacing: isHex ? 1.2 : 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimestampChip extends StatelessWidget {
  const _TimestampChip({required this.timestamp});
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final t = timestamp;
    final str =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        str,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _SparklineSection extends StatelessWidget {
  const _SparklineSection({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.show_chart_rounded,
                color: Color(0xFF4DB6AC), size: 16),
            const SizedBox(width: 6),
            const Text(
              'History (last 20)',
              style: TextStyle(
                color: Color(0xFF4DB6AC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'min ${minVal.toStringAsFixed(0)}  max ${maxVal.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: CustomPaint(
            painter: _SparklinePainter(values: values),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter that draws a smooth bezier sparkline with gradient fill.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range < 1 ? 1.0 : range;

    // Normalise to [0, 1].
    final norm = values
        .map((v) => 1.0 - (v - minVal) / effectiveRange)
        .toList();

    final dx = size.width / (values.length - 1);

    final points = List.generate(
      values.length,
      (i) => Offset(i * dx, norm[i] * size.height * 0.85 + size.height * 0.05),
    );

    // ── Gradient fill ────────────────────────────────────────────────────────
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF26C6DA).withOpacity(0.35),
          const Color(0xFF26C6DA).withOpacity(0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // ── Line (smooth bezier) ─────────────────────────────────────────────────
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF26C6DA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // ── Latest value dot ─────────────────────────────────────────────────────
    final dotPaint = Paint()
      ..color = const Color(0xFF26C6DA)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 4, dotPaint);

    final dotRingPaint = Paint()
      ..color = const Color(0xFF26C6DA).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 7, dotRingPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
