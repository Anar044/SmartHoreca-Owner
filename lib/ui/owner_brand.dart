import 'package:flutter/material.dart';

/// Shared approved Smart Horeca brand mark for launcher, splash and headers.
/// The image is included in the Android APK; no runtime network request.
class OwnerBrandMark extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;
  const OwnerBrandMark({super.key, this.size = 56, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * .22),
      child: Image.asset(
        'assets/brand/smart-horeca-logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Smart Horeca',
      ),
    );
  }
}
