import 'package:flutter/material.dart';

class ExceptionIcon extends StatelessWidget {
  const ExceptionIcon({
    super.key,
    this.size = 36,
    this.color = Colors.red,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_off_rounded,
      color: color,
      size: size,
    );
  }
}
