import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6), // Centered slightly above middle like the reference
          radius: 1.2,
          colors: [
            AppTheme.deepBlueGlow,
            AppTheme.backgroundBlack,
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}
