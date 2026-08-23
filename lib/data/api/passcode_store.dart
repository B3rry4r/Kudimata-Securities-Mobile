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
//
// 2026-08-14 (BUG-03): the passcode is now scoped to the email address that
// created it ([setPasscode]'s [owner] param, checked via [belongsTo]).
// Previously AppState.forceSignOut() unconditionally wiped the passcode on
// EVERY sign-out, including a plain voluntary "Sign out" from Account — so
// signing out and back in as the SAME person always forced passcode
// re-creation from scratch, defeating its whole purpose as a fast re-entry
// shortcut. Voluntary sign-out (AppState.signOut()) no longer wipes it;
// instead, log_in_screen.dart's post-login flow checks [belongsTo] against
// the freshly-authenticated account's real email and only reuses the
// existing passcode when it matches — a DIFFERENT account logging into this
// same device still gets a fresh create/confirm flow, same protection as
// before, just decided at the point it's actually knowable (login time,
// comparing accounts) rather than pessimistically on every sign-out.
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
  static const _ownerKey = 'kudimata.passcode.owner';

  /// Hash and persist [passcode], scoped to [owner] (the account's email —
  /// see [belongsTo]) — call once the create/confirm passcode flow has a
  /// confirmed match (see confirm_passcode_screen.dart). A fresh random
  /// salt is generated per set, so re-running this (e.g. a passcode reset,
  /// or a different account claiming this device) fully replaces the prior
  /// salt + hash + owner triple.
  Future<void> setPasscode(String passcode, {required String owner}) async {
    final salt = _generateSalt();
    final hash = _hash(passcode, salt);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _ownerKey, value: _normalize(owner));
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

  /// The account email that created the currently-stored passcode (if any),
  /// null if none is stored. Additive read-only accessor (2026-08-23
  /// exactness audit) — lets log_in_screen.dart's local-unlock "Forgot your
  /// password?" thread the already-known email into
  /// reset_passcode_screen.dart, matching canvas #s12 (which is reached
  /// with the email already known, no separate email-entry step). Does not
  /// change any existing call site.
  Future<String?> get owner => _storage.read(key: _ownerKey);

  /// Whether the currently-stored passcode (if any) was created by [owner]
  /// (an account email, compared case/whitespace-insensitively). False when
  /// no passcode is stored at all — same "nothing to check against" default
  /// as [verifyPasscode]. A fresh login only reuses the on-device passcode
  /// (skipping create/confirm) when this returns true for the newly
  /// authenticated account.
  Future<bool> belongsTo(String owner) async {
    final storedOwner = await _storage.read(key: _ownerKey);
    if (storedOwner == null) return false;
    return storedOwner == _normalize(owner);
  }

  /// Wipe the stored passcode hash + salt + owner — call on a genuine
  /// security-relevant sign-out (AppState.forceSignOut(): stale/invalid
  /// session, the explicit "reset passcode via password reset" flow) or
  /// when a fresh login's account doesn't match [belongsTo]. NOT called by
  /// AppState.signOut() (plain voluntary sign-out) — see file header.
  Future<void> clearPasscode() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _ownerKey);
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

  String _normalize(String email) => email.trim().toLowerCase();
}
