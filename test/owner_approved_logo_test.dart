import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/ui/owner_brand.dart';

void main() {
  testWidgets('SH Owner uses the approved uncropped brand image', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: OwnerBrandMark(size: 96))),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName,
        'assets/brand/sh-owner-original.png');
    expect(image.fit, BoxFit.contain);
    expect(find.byType(ClipRRect), findsNothing);
  });
}
