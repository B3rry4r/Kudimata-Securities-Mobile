// Kudimata Securities — local persistence for the investor's theme
// preference (R-13, docs/redesign/DECISIONS.md: system / light / dark,
// default system).
//
// Wraps flutter_secure_storage the same way AuthTokenStore and PasscodeStore
// do — see auth_token_store.dart for the pattern this follows. The value
// itself isn't sensitive; this repo's only established local-storage
// mechanism is this wrapper, so ThemeModeStore keeps that one mechanism
// rather than introducing a second (e.g. shared_preferences) for a single
// preference.
import 'package:flutter/material.dart' show ChangeNotifier, ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeModeStore {
  ThemeModeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'kudimata.theme.mode';

  Future<void> setThemeMode(ThemeMode mode) =>
      _storage.write(key: _key, value: mode.name);

  /// Reads the persisted preference. Defaults to [ThemeMode.system] — R-13's
  /// stated default — both when nothing has ever been written and when the
  /// stored string doesn't match a known [ThemeMode] name.
  Future<ThemeMode> getThemeMode() async {
    final raw = await _storage.read(key: _key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}

/// Live theme-mode preference, backed by [ThemeModeStore]. One instance for
/// the whole app ([instance]): main.dart's KudimataApp listens to it to pick
/// MaterialApp's `themeMode`, and the Account settings toggle
/// (security_screen.dart) calls [set] on this same instance. A static
/// singleton rather than something threaded through AppState/AppScope — the
/// same shape lib/theme/tokens.dart's `KColor.active` already uses for
/// cross-cutting theme state every screen needs without a BuildContext
/// lookup, kept here (next to the store it wraps) rather than duplicated.
class KThemePreference extends ChangeNotifier {
  KThemePreference({ThemeModeStore? store}) : _store = store ?? ThemeModeStore();

  static final KThemePreference instance = KThemePreference();

  final ThemeModeStore _store;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Resolves the persisted preference. [mode] reads [ThemeMode.system]
  /// synchronously until this completes, same "safe default, corrected once
  /// the async read returns" shape as AppState's signedIn/passcodeSet.
  Future<void> load() async {
    _mode = await _store.getThemeMode();
    notifyListeners();
  }

  Future<void> set(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _store.setThemeMode(mode);
  }
}
