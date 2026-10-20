import 'package:flutter/material.dart';
import '../ui/owner_brand.dart';

/// Branded launch while saved credentials and workspace are restored.
class OwnerSplashScreen extends StatelessWidget {
  const OwnerSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF091827),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OwnerBrandMark(size: 148),
              SizedBox(height: 26),
              Text('SMART HORECA', style: TextStyle(
                fontSize: 27, letterSpacing: 2,
                fontWeight: FontWeight.w900, color: Colors.white,
              )),
              SizedBox(height: 4),
              Text('Owner', style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w600,
                color: Color(0xFF71E4C5),
              )),
              SizedBox(height: 38),
              SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF5DD6D0))),
            ],
          ),
        ),
      ),
    );
  }
}
