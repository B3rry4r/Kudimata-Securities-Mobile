// Kudimata Securities — app entry. Boots the gated-flow → tab-shell router under a
// single AppState (AppScope). Light AND dark theming (R-13,
// docs/redesign/DECISIONS.md — see lib/theme/tokens.dart's header for why
// dark was removed and then reinstated). The investor's system/light/dark
// preference lives in KThemePreference.instance (lib/data/api/theme_mode_store.dart),
// a static singleton the Account settings toggle also writes to — see
// security_screen.dart. The Stage-1 gallery still lives at lib/gallery/ but
// is no longer referenced.
//
// Also constructs the single shared AuthTokenStore + ApiClient here, before the
// first frame, and wires ApiClient.onSessionExpired to this same AppState's
// forceSignOut(). Every screen/repository reaches the client via
// `AppScope.read(context).apiClient` / `AppScope.of(context).apiClient` — see
// lib/data/api/README.md; do not construct a second ApiClient anywhere else.
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app_state.dart';
import 'data/api/api_client.dart';
import 'data/api/auth_token_store.dart';
import 'data/api/theme_mode_store.dart';
import 'data/repositories/market_status_repository.dart';
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
    _state.addListener(_onState);
    // Prime AppState.isWatched() with the investor's real saved watchlist
    // once startup hydration (signedIn) resolves — see
    // AppState.hydrateWatchlist's doc comment. Only for a returning,
    // already-signed-in session; a fresh sign-in/sign-up has nothing to
    // hydrate yet and its own flows populate the watchlist as it's used.
    _state.ready.then((_) {
      if (_state.signedIn) {
        _state.hydrateWatchlist(WatchlistRepository(_state.apiClient));
        _state.startMarketStatusPolling(MarketStatusRepository(_state.apiClient));
      }
    });
    // Theme preference: starts at ThemeMode.system synchronously (see
    // KThemePreference), then resolves the persisted choice.
    KThemePreference.instance.addListener(_onState);
    KThemePreference.instance.load();
    // "System" needs a live update if the OS theme flips while the app is
    // open — WidgetsBindingObserver.didChangePlatformBrightness is the
    // notification for that; MediaQuery alone wouldn't rebuild anything
    // outside the widget tree MaterialApp has already built.
    WidgetsBinding.instance.addObserver(this);
  }

  void _onState() => setState(() {});

  @override
  void didChangePlatformBrightness() {
    if (KThemePreference.instance.mode == ThemeMode.system) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KThemePreference.instance.removeListener(_onState);
    _state.removeListener(_onState);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = KThemePreference.instance.mode;
    // Resolve which palette KColor.x (our own widgets, not MaterialApp's
    // Material defaults) should read this frame. PlatformDispatcher, not
    // MediaQuery — this runs before MaterialApp has built anything that
    // could provide a MediaQuery, same reason MaterialApp itself resolves
    // `themeMode: system` this way internally.
    final systemIsDark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final resolvedDark = mode == ThemeMode.dark || (mode == ThemeMode.system && systemIsDark);
    // Set the active palette BEFORE the subtree builds so every KColor.x read
    // (in our custom widgets) returns the themed colour this frame.
    KColor.active = resolvedDark ? KPalette.dark : KPalette.light;

    return AppScope(
      state: _state,
      child: MaterialApp.router(
        title: 'Kudimata Invest',
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        darkTheme: KTheme.dark(),
        themeMode: mode,
        routerConfig: _router,
      ),
    );
  }
}
