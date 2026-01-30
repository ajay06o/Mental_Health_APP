import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color color;

  const AppLogo({
    super.key,
    this.size = 64,
    this.color = Colors.indigo,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.self_improvement,
      size: size,
      color: color,
    );
  }
}
