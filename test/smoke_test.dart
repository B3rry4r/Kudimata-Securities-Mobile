import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudimata_securities/theme/app_theme.dart';
import 'package:kudimata_securities/gallery/gallery_screen.dart';

void main() {
  testWidgets('Stage 1 gallery builds without exceptions', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: KTheme.light(), home: const GalleryScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GalleryScreen), findsOneWidget);
  });
}
