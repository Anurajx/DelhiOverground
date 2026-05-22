import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:metroapp/main.dart';

void main() {
  testWidgets('App boots smoke test', (WidgetTester tester) async {
    // Set screen size to a wide viewport to accommodate mock test fonts (which are wider) without overflowing
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dataProvider = DataProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<DataProvider>.value(
        value: dataProvider,
        child: const MyApp(),
      ),
    );

    // Verify that the App builds and displays the MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
