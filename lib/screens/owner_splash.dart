import 'package:flutter/material.dart';
import '../ui/owner_brand.dart';

/// Brand-first launch screen, inspired by the approved restaurant splash.
/// It supports dark, light and system appearance without stretching a photo
/// or placing mobile screenshots inside the actual app UI.
class OwnerSplashScreen extends StatelessWidget {
  const OwnerSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const navy = Color(0xFF0B1728);
    const mint = Color(0xFF76E2CF);
    const blue = Color(0xFF4C9EFF);
    const ink = Color(0xFF132844);
    final background = dark ? navy : const Color(0xFFF7FAFF);
    final headline = dark ? Colors.white : ink;
    final subtitle = dark
        ? const Color(0xFFCEDBEC)
        : const Color(0xFF64748B);
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF081321), Color(0xFF132C40),
                        Color(0xFF07111E)]
                    : const [Color(0xFFF9FBFF), Color(0xFFF0F7FF),
                        Color(0xFFE9F9F6)],
              ),
            ),
          ),
          // Very soft colored halos echo the blue-green brand symbol.
          Positioned(
            top: -100, left: -140,
            child: _BrandHalo(
              diameter: 350,
              color: dark ? const Color(0xFF155D86) : const Color(0xFFD5E9FD),
            ),
          ),
          Positioned(
            bottom: -220, right: -130,
            child: _BrandHalo(
              diameter: 490,
              color: dark ? const Color(0xFF105749) : const Color(0xFFCFEDE7),
            ),
          ),
          Positioned(
            bottom: 96, left: -80,
            child: _BrandHalo(
              diameter: 260,
              color: dark ? const Color(0xFF173B65) : const Color(0xFFDCE8FF),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 600;
                final logoSize = compact ? 108.0 : 140.0;
                return Column(
                  children: [
                    const Spacer(flex: 3),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: dark
                              ? const Color(0x5576E2CF)
                              : const Color(0x6676B9E2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (dark ? mint : blue).withValues(alpha: 0.17),
                            blurRadius: 42,
                            spreadRadius: 7,
                          ),
                        ],
                      ),
                      child: OwnerBrandMark(
                        size: logoSize,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    SizedBox(height: compact ? 22 : 32),
                    Text(
                      'SMART HORECA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: headline,
                        fontSize: compact ? 25 : 30,
                        letterSpacing: 1.9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) =>
                          const LinearGradient(colors: [blue, mint])
                              .createShader(rect),
                      child: const Text(
                        'Owner',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 26),
                    Container(
                      width: 58,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(colors: [blue, mint]),
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 27),
                    Text(
                      'Ваш бизнес всегда под контролем',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtitle,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(flex: 3),
                    const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: mint,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SH Owner',
                      style: TextStyle(
                        color: subtitle,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHalo extends StatelessWidget {
  final double diameter;
  final Color color;
  const _BrandHalo({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
