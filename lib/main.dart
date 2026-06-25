// Kudimata Securities — app entry. Stage 1 boots straight into the design-system
// gallery for review. Later stages replace `home` with the go_router shell
// (gated flow → tabs) per the Flow Map.
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'gallery/gallery_screen.dart';

void main() => runApp(const KudimataApp());

class KudimataApp extends StatelessWidget {
  const KudimataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kudimata Securities',
      debugShowCheckedModeBanner: false,
      theme: KTheme.light(),
      home: const GalleryScreen(),
    );
  }
}
