// Kudimata Securities — app entry. Boots the gated-flow → tab-shell router under a
// single AppState (AppScope), with light/dark theming driven by AppState.themeMode
// (System / Light / Dark). The Stage-1 gallery still lives at lib/gallery/ but is
// no longer referenced.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app_state.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() => runApp(const KudimataApp());

class KudimataApp extends StatefulWidget {
  const KudimataApp({super.key});

  @override
  State<KudimataApp> createState() => _KudimataAppState();
}

class _KudimataAppState extends State<KudimataApp> with WidgetsBindingObserver {
  // Single session-state instance; the router gate listens to it.
  final AppState _state = AppState();
  late final GoRouter _router = buildRouter(_state);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.addListener(_onState);
  }

  void _onState() => setState(() {}); // re-resolve brightness on themeMode change

  @override
  void didChangePlatformBrightness() {
    // OS light/dark changed — re-resolve our palette and rebuild every screen
    // (the per-route ListenableBuilders listen to AppState).
    setState(() {});
    _state.refreshTheme();
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  Brightness _resolve() {
    switch (_state.themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set the active palette BEFORE the subtree builds so every KColor.x read
    // (in our custom widgets) returns the themed colour this frame.
    KColor.active = _resolve() == Brightness.dark ? KPalette.dark : KPalette.light;

    return AppScope(
      state: _state,
      child: MaterialApp.router(
        title: 'Kudimata Securities',
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        darkTheme: KTheme.dark(),
        themeMode: _state.themeMode,
        routerConfig: _router,
      ),
    );
  }
}
