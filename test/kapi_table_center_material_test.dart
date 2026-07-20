import 'package:dominoes_note2025/widgets/kapi_table_center_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('game table crops the shop preview to its center material', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: KapiTableCenterMaterial(
            fallbackColor: Color(0xFF064C3B),
            assetPath: 'assets/kapi_shop/tables/table_mahogany.png',
          ),
        ),
      ),
    );

    final transform = tester.widget<Transform>(
      find.byKey(KapiTableCenterMaterial.imageKey),
    );
    final image = tester.widget<Image>(find.byType(Image));

    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.75, 0.001));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
  });
}
