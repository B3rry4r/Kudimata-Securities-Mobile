// Kudimata Securities — local persistence for whether the signed-in
// investor has ever had a risk-disclosure acceptance recorded at the point
// of first trade.
//
// This is NOT the deleted `AppState.riskDisclosureAccepted` (removed
// 2026-08-31, R-51, docs/redesign/DECISIONS.md) — that flag gated
// onboarding and does not come back. This is a different thing at a
// different point in the flow: a record, written the moment an order
// genuinely succeeds (see trade_flows.dart's `_BuyReviewSheetState._confirm`
// — never at the moment the checkbox is ticked), that trade_flows.dart's
// order-confirmation step reads to decide whether to show its
// `KLinkedCheckbox` ("I have read the **Risk Disclosure**") again. Nothing
// in the router or `_gateRedirect` reads this — it only ever affects
// whether one checkbox renders on the NEXT order.
//
// Wraps flutter_secure_storage the same way AuthTokenStore/PasscodeStore/
// ThemeModeStore do — see auth_token_store.dart for the pattern this
// follows. Scoped PER INVESTOR the way PasscodeStore is (see that file's
// header and its `owner`/`belongsTo` pair), deliberately NOT device-global
// the way ThemeModeStore is: a single unscoped flag is the right shape for
// "system/light/dark", wrong for a compliance acknowledgement that belongs
// to one person. A shared or resold handset, or a second account signing
// into this same device, must not inherit a stranger's acceptance.
//
// Same single-slot shape as PasscodeStore's owner tag (this app supports
// one signed-in-with-a-local-passcode investor per device at a time, not
// several persisted side by side): [hasAccepted] only returns true when the
// stored owner matches the [owner] asked about, so a different investor —
// which already forces a fresh create/confirm passcode flow on this same
// device, per PasscodeStore's own header — is asked again rather than
// silently inheriting someone else's acceptance. A missing record (fresh
// install, cleared storage, never-written key) also reads as "not
// accepted" — the safe fallback is always to ask again, never to assume.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RiskDisclosureStore {
  RiskDisclosureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ownerKey = 'kudimata.riskDisclosure.acceptedOwner';

  /// Record that [owner] has accepted the risk disclosure. Call ONLY once
  /// an order has actually been placed successfully
  /// (`OrderPlacementRepository.placeOrder` returned, not merely called) —
  /// ticking the checkbox is not acceptance. An investor who ticks it and
  /// then the order fails, or who cancels/backs out at the passcode prompt,
  /// has not traded yet and must see the checkbox again next time.
  Future<void> recordAccepted(String owner) =>
      _storage.write(key: _ownerKey, value: _normalize(owner));

  /// Whether [owner] has a recorded acceptance on this device. False for
  /// any other owner (even one who has genuinely accepted before — that
  /// acceptance belongs to them, not to whoever is asking now) and false
  /// when nothing has ever been written.
  Future<bool> hasAccepted(String owner) async {
    final stored = await _storage.read(key: _ownerKey);
    return stored != null && stored == _normalize(owner);
  }

  /// Wipe the record — call on a genuine forced sign-out
  /// (`AppState.forceSignOut`, alongside `PasscodeStore.clearPasscode`) so a
  /// security-relevant sign-out doesn't leave a stale acceptance sitting on
  /// the device for whoever unlocks it next. NOT called by a plain
  /// voluntary "Sign out" — same split PasscodeStore itself draws, so the
  /// same investor signing back in still skips the checkbox they've already
  /// seen, and a genuinely different investor is caught by the owner
  /// mismatch in [hasAccepted] regardless.
  Future<void> clearAccepted() => _storage.delete(key: _ownerKey);

  String _normalize(String email) => email.trim().toLowerCase();
}
