// Kudimata Securities — secure persistence for the investor auth session.
//
// Wraps flutter_secure_storage (Keychain on iOS, Keystore-backed encrypted
// prefs on Android). This is the "secure store" lib/app/app_state.dart's
// original header comment said would "plug in later" — it now does, via
// AppState's `forceSignOut()` and its constructor-time hydration.
//
// Investor tokens only (.pipeline/conventions.md: investor realm access
// token ~15 min TTL, rotating refresh token ~30 days). Staff auth belongs to
// the separate dashboard app, not this mobile app.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'kudimata.auth.accessToken';
  static const _refreshKey = 'kudimata.auth.refreshToken';

  /// Persist a fresh token pair — call after login / verify-email-otp /
  /// refresh, whose responses all carry `accessToken` (+ `refreshToken` for
  /// investor sessions) per src/auth/auth.types.ts on the backend.
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  /// Wipe both tokens — call on explicit sign-out and on AppState.forceSignOut().
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
