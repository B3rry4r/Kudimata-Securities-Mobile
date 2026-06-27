// Kudimata Securities — minimal app session state. Drives the gated-flow router
// (passcode → biometric → KYC → suitability → tabs) and the live watchlist set.
// SEAM: real auth/KYC/suitability outcomes flip these flags; here they are flipped
// by the demo flows. No persistence yet (a secure store plugs in later).
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

class AppState extends ChangeNotifier {
  AppState({Set<String>? watchlistTickers})
      : _watchlist = watchlistTickers ?? {'MTNN', 'AAPL', 'TSLA', 'DANGCEM'};

  // Onboarding / gate flags.
  bool passcodeSet = false;
  bool biometricEnabled = false;
  bool kycSubmitted = false;
  bool kycApproved = false;
  bool suitabilityComplete = false;
  bool signedIn = false;

  // Appearance — System / Light / Dark (SEAM: persist to a store later).
  ThemeMode themeMode = ThemeMode.system;

  // Live watchlist (tickers).
  final Set<String> _watchlist;
  Set<String> get watchlistTickers => Set.unmodifiable(_watchlist);
  bool isWatched(String ticker) => _watchlist.contains(ticker);

  void setPasscode(bool v) {
    passcodeSet = v;
    notifyListeners();
  }

  void setBiometric(bool v) {
    biometricEnabled = v;
    notifyListeners();
  }

  void setKycSubmitted(bool v) {
    kycSubmitted = v;
    notifyListeners();
  }

  void setKycApproved(bool v) {
    kycApproved = v;
    notifyListeners();
  }

  void setSuitabilityComplete(bool v) {
    suitabilityComplete = v;
    notifyListeners();
  }

  void setSignedIn(bool v) {
    signedIn = v;
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    if (m == themeMode) return;
    themeMode = m;
    notifyListeners();
  }

  /// Force theme-dependent rebuilds (e.g. when the OS brightness changes while
  /// in System mode). No state change — just nudges listeners to re-read KColor.
  void refreshTheme() => notifyListeners();

  void toggleWatch(String ticker) {
    if (!_watchlist.remove(ticker)) _watchlist.add(ticker);
    notifyListeners();
  }

  void addWatch(String ticker) {
    if (_watchlist.add(ticker)) notifyListeners();
  }

  void removeWatch(String ticker) {
    if (_watchlist.remove(ticker)) notifyListeners();
  }
}

/// InheritedNotifier exposing the single [AppState]. Wrap the app once; read it
/// with `AppScope.of(context)` (rebuilds on change) or `AppScope.read(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Listening read — rebuilds the caller when [AppState] notifies.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }

  /// Non-listening read — for event handlers that only mutate.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
