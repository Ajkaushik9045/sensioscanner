import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ble/domain/entities/characteristic_value.dart';
import '../../domain/vital_sign_parser.dart';
import '../../../../core/services/ble_uuid_names.dart';

/// A premium health dashboard that displays live vital signs in a 2×2 grid
/// of animated cards. Designed for the SensioVital multi-stream mode.
class VitalsDashboard extends StatelessWidget {
  const VitalsDashboard({
    super.key,
    required this.latestValues,
    required this.histories,
  });

  /// Latest value per characteristic UUID.
  final Map<String, CharacteristicValue> latestValues;

  /// History per characteristic UUID (up to 20 values each).
  final Map<String, List<CharacteristicValue>> histories;

  @override
  Widget build(BuildContext context) {
    // Detect if we are connecting to a Ring device based on service or characteristic UUIDs
    final isRing = latestValues.values.any((cv) =>
        cv.serviceUuid.toLowerCase() == kSensioRingServiceUuid.toLowerCase() ||
        cv.characteristicUuid.toLowerCase() == kSensioRingHrvStressCharUuid.toLowerCase() ||
        cv.characteristicUuid.toLowerCase() == kSensioRingStepsCharUuid.toLowerCase() ||
        cv.characteristicUuid.toLowerCase() == kSensioRingSkinTempCharUuid.toLowerCase() ||
        cv.characteristicUuid.toLowerCase() == kBtSigSpo2PlxCharUuid.toLowerCase());

    // Initialize standard vitals with placeholders to avoid layout pop-in.
    final vitalsMap = isRing
        ? <VitalType, ParsedVitalSign>{
            VitalType.hrv: getPlaceholderVital(VitalType.hrv),
            VitalType.stress: getPlaceholderVital(VitalType.stress),
            VitalType.steps: getPlaceholderVital(VitalType.steps),
            VitalType.skinTemp: getPlaceholderVital(VitalType.skinTemp),
            VitalType.spo2: getPlaceholderVital(VitalType.spo2),
          }
        : <VitalType, ParsedVitalSign>{
            VitalType.heartRate: getPlaceholderVital(VitalType.heartRate),
            VitalType.spo2: getPlaceholderVital(VitalType.spo2),
            VitalType.temperature: getPlaceholderVital(VitalType.temperature),
            VitalType.battery: getPlaceholderVital(VitalType.battery),
          };

    final vitalHistories = <VitalType, List<double>>{};

    // Overlay any received values.
    for (final entry in latestValues.entries) {
      final uuid = entry.key;
      final cv = entry.value;
      final parsedList = parseVitalSigns(cv);
      for (final parsed in parsedList) {
        vitalsMap[parsed.type] = parsed;

        // Extract numeric history for sparklines.
        final hist = histories[uuid] ?? [];
        final nums = <double>[];
        for (final h in hist) {
          final pList = parseVitalSigns(h);
          for (final p in pList) {
            if (p.type == parsed.type) {
              nums.add(p.value);
            }
          }
        }
        vitalHistories[parsed.type] = nums;
      }
    }

    // Convert to list sorted in standard order.
    final parsedVitals = vitalsMap.values.toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));

    final activeVitals = <VitalType>{};
    for (final entry in latestValues.entries) {
      final parsedList = parseVitalSigns(entry.value);
      for (final p in parsedList) {
        activeVitals.add(p.type);
      }
    }
    final activeCount = activeVitals.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dashboard Header ──────────────────────────────────────────────
          _DashboardHeader(vitalsCount: activeCount),
          const SizedBox(height: 12),

          // ── Vital Cards Grid ──────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: parsedVitals.length,
            itemBuilder: (context, index) {
              final vital = parsedVitals[index];
              final history = vitalHistories[vital.type] ?? [];
              return _VitalCard(
                vital: vital,
                history: history,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Header ─────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.vitalsCount});
  final int vitalsCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A5C), Color(0xFF0D2137)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            color: Color(0xFF26C6DA),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Vitals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '$vitalsCount vital signs streaming',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _PulsingDot(color: const Color(0xFF4CAF50)),
      ],
    );
  }
}

// ── Vital Card ───────────────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  const _VitalCard({
    required this.vital,
    required this.history,
  });

  final ParsedVitalSign vital;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1E35),
            vital.color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: vital.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: vital.color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon + Label Row ──────────────────────────────────────────
            Row(
              children: [
                _VitalIcon(vital: vital),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vital.label,
                    style: TextStyle(
                      color: vital.color.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // ── Large Value ────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      vital.displayValue,
                      key: ValueKey(vital.displayValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    vital.unit,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Status Badge ──────────────────────────────────────────────
            _StatusBadge(vital: vital),
            const SizedBox(height: 8),

            // ── Mini Sparkline ─────────────────────────────────────────────
            if (history.length >= 2)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CustomPaint(
                    painter: _MiniSparklinePainter(
                      values: history,
                      color: vital.color,
                    ),
                    size: Size.infinite,
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    'Collecting data…',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Vital Icon with pulse animation ──────────────────────────────────────────

class _VitalIcon extends StatefulWidget {
  const _VitalIcon({required this.vital});
  final ParsedVitalSign vital;

  @override
  State<_VitalIcon> createState() => _VitalIconState();
}

class _VitalIconState extends State<_VitalIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.vital.type == VitalType.heartRate
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 2000),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: widget.vital.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          widget.vital.icon,
          color: widget.vital.color,
          size: 18,
        ),
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.vital});
  final ParsedVitalSign vital;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: vital.statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: vital.statusColor.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: vital.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              vital.statusMessage,
              style: TextStyle(
                color: vital.statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Live Dot ─────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              color: widget.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini Sparkline Painter ───────────────────────────────────────────────────

class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range < 0.1 ? 1.0 : range;

    final norm = values
        .map((v) => 1.0 - (v - minVal) / effectiveRange)
        .toList();

    final dx = size.width / (values.length - 1);

    final points = List.generate(
      values.length,
      (i) => Offset(
        i * dx,
        norm[i] * size.height * 0.8 + size.height * 0.1,
      ),
    );

    // ── Gradient fill ──────────────────────────────────────────────────────
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
          color.withOpacity(0.3),
          color.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // ── Smooth line ────────────────────────────────────────────────────────
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
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // ── Latest dot ─────────────────────────────────────────────────────────
    canvas.drawCircle(points.last, 3, Paint()..color = color);
    canvas.drawCircle(
      points.last,
      5,
      Paint()..color = color.withOpacity(0.3),
    );
  }

  @override
  bool shouldRepaint(_MiniSparklinePainter old) =>
      old.values != values || old.color != color;
}
