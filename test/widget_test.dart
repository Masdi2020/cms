import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cms/main.dart';

void main() {
  testWidgets('Rukun loads its branding asset', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Rukun'), findsOneWidget);
    expect(find.text('Bersama, lebih tertata.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
