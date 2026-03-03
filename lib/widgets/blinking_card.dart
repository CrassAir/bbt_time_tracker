import 'package:flutter/material.dart';

class BlinkingCard extends StatefulWidget {
  final Widget child;
  final Color? activeColor;
  final bool isActive;
  final double borderRadius;

  const BlinkingCard({
    super.key,
    required this.child,
    this.activeColor,
    this.isActive = false,
    this.borderRadius = 12,
  });

  @override
  State<BlinkingCard> createState() => _BlinkingCardState();
}

class _BlinkingCardState extends State<BlinkingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BlinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.isActive
                  ? (widget.activeColor ?? Colors.blue).withValues(
                      alpha: _animation.value)
                  : Colors.grey.shade800,
              width: widget.isActive ? 2 : 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: (widget.activeColor ?? Colors.blue)
                          .withValues(alpha: 0.2 * _animation.value),
                      blurRadius: 12 * _animation.value,
                      spreadRadius: 2 * _animation.value,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
