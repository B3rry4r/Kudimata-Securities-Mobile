// Kudimata Securities — app entry. Boots the gated-flow → tab-shell router under a
// single AppState (AppScope) and the Stage-1 theme. The Stage-1 design gallery
// still lives at lib/gallery/ but is no longer referenced.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app_state.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() => runApp(const KudimataApp());

class KudimataApp extends StatefulWidget {
  const KudimataApp({super.key});

  @override
  State<KudimataApp> createState() => _KudimataAppState();
}

class _KudimataAppState extends State<KudimataApp> {
  // Single session-state instance; the router gate listens to it.
  final AppState _state = AppState();
  late final GoRouter _router = buildRouter(_state);

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp.router(
        title: 'Kudimata Securities',
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
