// Kudimata Securities — secure local persistence for the investor's 6-digit
// app passcode.
//
// Wraps flutter_secure_storage the same way AuthTokenStore does (Keychain on
// iOS, Keystore-backed encrypted prefs on Android) — see auth_token_store.dart
// for the pattern this follows. The raw passcode is never written to disk:
// we store a SHA-256 hash salted with a random per-install value (also kept
// in secure storage), so a leaked/rooted-device read of the store still
// can't recover the passcode digits directly.
//
// This is LOCAL unlock verification only — a fast, offline "is this the
// passcode this device's owner chose" check. It is layered in front of, not
// instead of, the server-side session validity check log_in_screen.dart
// already performs (GET /users/me) — see that screen for how the two compose.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasscodeStore {
  PasscodeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _hashKey = 'kudimata.passcode.hash';
  static const _saltKey = 'kudimata.passcode.salt';

  /// Hash and persist [passcode] — call once the create/confirm passcode
  /// flow has a confirmed match (see confirm_passcode_screen.dart). A fresh
  /// random salt is generated per set, so re-running this (e.g. a passcode
  /// reset) fully replaces the prior salt + hash pair.
  Future<void> setPasscode(String passcode) async {
    final salt = _generateSalt();
    final hash = _hash(passcode, salt);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hash);
  }

  /// Hash [passcode] with the stored salt and compare against the stored
  /// hash. Returns false (rather than throwing) if no passcode has ever been
  /// set on this device — callers should gate on [hasPasscode] first to
  /// distinguish "wrong passcode" from "nothing to check against".
  Future<bool> verifyPasscode(String passcode) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(passcode, salt) == storedHash;
  }

  /// Whether a passcode has ever been persisted on this device.
  Future<bool> hasPasscode() async {
    final storedHash = await _storage.read(key: _hashKey);
    return storedHash != null && storedHash.isNotEmpty;
  }

  /// Wipe the stored passcode hash + salt — call on explicit sign-out and on
  /// AppState.forceSignOut(), same as AuthTokenStore.clearTokens().
  Future<void> clearPasscode() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _hash(String passcode, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$passcode'));
    return digest.toString();
  }

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }
}
