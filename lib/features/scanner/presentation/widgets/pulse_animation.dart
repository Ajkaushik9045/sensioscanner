import 'package:flutter/material.dart';

class PulseAnimation extends StatefulWidget {
  const PulseAnimation({super.key, required this.child});
  final Widget child;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation> with SingleTickerProviderStateMixin {
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
