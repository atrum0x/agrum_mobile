import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// The web app's logo (agrum_fe/src/assets). [animated] plays the logo animation, used while
/// the app is busy (logging in, restoring the session).
class AgrumLogo extends StatelessWidget {
  const AgrumLogo({super.key, this.size = 96, this.animated = false});

  final double size;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final still = Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain);
    if (!animated) return still;
    return Lottie.asset(
      'assets/logo.json',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Show the still logo until the animation is parsed, so the space never flashes empty.
      frameBuilder: (context, child, composition) => composition == null ? still : child,
    );
  }
}
