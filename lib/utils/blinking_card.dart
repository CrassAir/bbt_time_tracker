import 'package:flutter/material.dart';

class BlinkingCard extends StatefulWidget {
  final Widget child;
  final bool isBlinking;
  final Color defaultColor;

  const BlinkingCard({super.key, required this.child, required this.defaultColor, this.isBlinking = false});

  @override
  State<BlinkingCard> createState() => _BlinkingCardState();
}

class _BlinkingCardState extends State<BlinkingCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: 300), vsync: this);
  }

  @override
  void didUpdateWidget(BlinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBlinking) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.reset();
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
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isBlinking ? Color.lerp(Colors.red.shade200, Colors.red.shade300, _controller.value) : widget.defaultColor,
          ),
          child: widget.child,
        );
      },
    );
  }
}
