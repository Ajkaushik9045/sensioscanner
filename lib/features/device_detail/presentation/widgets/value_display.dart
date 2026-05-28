import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ble/domain/entities/characteristic_value.dart';
import '../../domain/vital_sign_parser.dart';

/// Displays a live characteristic value.
///
/// For known vital signs (HR, SpO₂, Temperature, Battery), shows a rich
/// parsed card with value, unit, status, and sparkline.
/// For unknown characteristics, falls back to HEX / DEC / UTF-8 display.
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
    // Try to parse as a known vital sign.
    final parsed = parseVitalSign(latestValue);

    if (parsed != null) {
      final numericHistory = <double>[];
      for (final h in history) {
        final p = parseVitalSign(h);
        if (p != null) numericHistory.add(p.value);
      }
      return _ParsedVitalDisplay(
        vital: parsed,
        numericHistory: numericHistory,
        rawValue: latestValue,
      );
    }

    // Fallback: raw display.
    return _RawValueDisplay(latestValue: latestValue, history: history);
  }
}

// ── Parsed Vital Display ─────────────────────────────────────────────────────

class _ParsedVitalDisplay extends StatelessWidget {
  const _ParsedVitalDisplay({
    required this.vital,
    required this.numericHistory,
    required this.rawValue,
  });

  final ParsedVitalSign vital;
  final List<double> numericHistory;
  final CharacteristicValue rawValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D1E35),
            vital.color.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vital.color.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: vital.color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(vital.icon, color: vital.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vital.label,
                        style: TextStyle(
                          color: vital.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    _TimestampChip(timestamp: rawValue.timestamp),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Large Value ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        vital.displayValue,
                        key: ValueKey(vital.displayValue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        vital.unit,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Status Badge ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: vital.statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: vital.statusColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: vital.statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: vital.statusColor.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        vital.statusMessage,
                        style: TextStyle(
                          color: vital.statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sparkline ──────────────────────────────────────────────────────
          if (numericHistory.length >= 2) ...[
            const Divider(color: Color(0xFF1E3A5F), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SparklineSection(
                values: numericHistory,
                color: vital.color,
              ),
            ),
          ],

          // ── Raw Data (collapsible) ──────────────────────────────────────────
          _RawDataExpander(rawValue: rawValue),
        ],
      ),
    );
  }
}

// ── Raw Data Expander ────────────────────────────────────────────────────────

class _RawDataExpander extends StatefulWidget {
  const _RawDataExpander({required this.rawValue});
  final CharacteristicValue rawValue;

  @override
  State<_RawDataExpander> createState() => _RawDataExpanderState();
}

class _RawDataExpanderState extends State<_RawDataExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.code_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Raw Data',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Column(
              children: [
                _RawRow(label: 'HEX', value: widget.rawValue.hexString, color: const Color(0xFF80DEEA)),
                const SizedBox(height: 4),
                _RawRow(label: 'DEC', value: _toDecimal(widget.rawValue), color: const Color(0xFF80CBC4)),
                const SizedBox(height: 4),
                _RawRow(label: 'UTF-8', value: _toUtf8(widget.rawValue), color: const Color(0xFF90CAF9)),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
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
    if (s == v.hexString) return '(non-printable)';
    return s;
  }
}

class _RawRow extends StatelessWidget {
  const _RawRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isCopyable = value != '—' && value != '(non-printable)';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCopyable
            ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (isCopyable) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.copy_rounded,
                  color: Colors.white.withOpacity(0.25),
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Raw Value Display (fallback for unknown characteristics) ──────────────────

class _RawValueDisplay extends StatelessWidget {
  const _RawValueDisplay({required this.latestValue, required this.history});

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
            _SparklineSection(
              values: numericValues,
              color: const Color(0xFF26C6DA),
            ),
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
    final isCopyable = value != '—' && value != '(non-printable)';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCopyable
            ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              if (isCopyable) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.copy_rounded,
                  color: Colors.white.withOpacity(0.25),
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
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
  const _SparklineSection({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart_rounded, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              'History (last ${values.length})',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'min ${minVal.toStringAsFixed(1)}  max ${maxVal.toStringAsFixed(1)}',
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
            painter: _SparklinePainter(values: values, color: color),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter that draws a smooth bezier sparkline with gradient fill.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range < 0.1 ? 1.0 : range;

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
          color.withOpacity(0.35),
          color.withOpacity(0.01),
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
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // ── Latest value dot ─────────────────────────────────────────────────────
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 4, dotPaint);

    final dotRingPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 7, dotRingPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
