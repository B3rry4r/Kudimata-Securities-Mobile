// Kudimata Securities — app entry. Boots the gated-flow → tab-shell router under a
// single AppState (AppScope), with light/dark theming driven by AppState.themeMode
// (System / Light / Dark). The Stage-1 gallery still lives at lib/gallery/ but is
// no longer referenced.
//
// Also constructs the single shared AuthTokenStore + ApiClient here, before the
// first frame, and wires ApiClient.onSessionExpired to this same AppState's
// forceSignOut(). Every screen/repository reaches the client via
// `AppScope.read(context).apiClient` / `AppScope.of(context).apiClient` — see
// lib/data/api/README.md; do not construct a second ApiClient anywhere else.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app_state.dart';
import 'data/api/api_client.dart';
import 'data/api/auth_token_store.dart';
import 'data/repositories/watchlist_repository.dart';
import 'router/app_router.dart';
import 'screens/kyc/kyc_form_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() => runApp(const KudimataApp());

class KudimataApp extends StatefulWidget {
  const KudimataApp({super.key});

  @override
  State<KudimataApp> createState() => _KudimataAppState();
}

class _KudimataAppState extends State<KudimataApp> with WidgetsBindingObserver {
  // Single session-state instance; the router gate listens to it. Single
  // shared token store, handed to both AppState (local signedIn hydration)
  // and ApiClient (auth header / refresh), so both agree on one token pair.
  final AuthTokenStore _tokenStore = AuthTokenStore();
  late final AppState _state = AppState(tokenStore: _tokenStore);
  late final GoRouter _router = buildRouter(_state);

  @override
  void initState() {
    super.initState();
    // Single shared ApiClient, constructed before the first frame. Its
    // onSessionExpired callback closes the loop from Task 2's 401-refresh
    // failure path back to this exact AppState instance's forceSignOut().
    _state.apiClient = ApiClient(tokenStore: _tokenStore, onSessionExpired: _state.forceSignOut);
    // Single shared KYC form holder — see lib/screens/kyc/kyc_form_state.dart.
    _state.kycForm = KycFormState();
    WidgetsBinding.instance.addObserver(this);
    _state.addListener(_onState);
    // Prime AppState.isWatched() with the investor's real saved watchlist
    // once startup hydration (signedIn) resolves — see
    // AppState.hydrateWatchlist's doc comment. Only for a returning,
    // already-signed-in session; a fresh sign-in/sign-up has nothing to
    // hydrate yet and its own flows populate the watchlist as it's used.
    _state.ready.then((_) {
      if (_state.signedIn) {
        _state.hydrateWatchlist(WatchlistRepository(_state.apiClient));
      }
    });
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
        title: 'Kudimata Invest',
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        darkTheme: KTheme.dark(),
        themeMode: _state.themeMode,
        routerConfig: _router,
      ),
    );
  }
}
