import 'package:flutter/material.dart';

/// The approved SH Owner artwork. Preserve its own rounded edges and glow:
/// never add another crop, tint, border or generated background.
class OwnerBrandMark extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius; // Legacy caller API; artwork masks itself.
  const OwnerBrandMark({super.key, this.size = 56, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/sh-owner-original.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'SH Owner',
    );
  }
}
