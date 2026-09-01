// Kudimata Securities — Auth repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = AuthRepository(AppScope.read(context).apiClient);
//
// registry.json's AuthSession resource lists POST /auth/signup as pre-auth
// (`"roles": []`) — ApiClient's `_preAuthPaths` already exempts it from the
// Authorization header / 401-refresh dance, so no extra guard is needed here.
import '../api/api_client.dart';

/// The two fields the OTP screen persists from a POST /auth/verify-email-otp
/// response. Per Kudimata-Securities-Backend src/auth/auth.types.ts
/// (AuthSessionWithTokens), that response extends the frozen `AuthSession`
/// shape with `accessToken` (always present) and `refreshToken` (investor
/// sessions only — always present for this app's investor-only flow).
class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});
  final String accessToken;
  final String? refreshToken;
}

/// POST /auth/login's response, parsed as one of two shapes (see [login]):
/// either a normal [AuthTokens] session, or — when the investor's carried-
/// forward `stepUpAuthEnabled` preference (account-security screen's
/// two-factor switch) is on — no tokens at all, just the `EmailOtp` the
/// backend just dispatched, meaning the caller must collect the emailed code
/// and redeem it via [AuthRepository.verifyEmailOtp] (same endpoint the
/// sign-up OTP screen uses — the backend tries the `signup_verify` purpose
/// first and falls back to `step_up` automatically, so no separate
/// "verify step-up" method is needed here) before a session actually exists.
class LoginResult {
  const LoginResult.session(this.tokens) : stepUpRequired = false;
  const LoginResult.stepUp()
      : tokens = null,
        stepUpRequired = true;

  /// Non-null exactly when [stepUpRequired] is false.
  final AuthTokens? tokens;
  final bool stepUpRequired;
}

class AuthRepository {
  const AuthRepository(this._client);
  final ApiClient _client;

  /// Mirrors the sign-up screen's Continue action. POST /auth/signup
  /// {email, password, firstName, middleName?, lastName, phone?} —
  /// registry.json's response shape is `EmailOtp`, but no screen renders any
  /// of its fields yet (the OTP screen still shows a static demo address),
  /// so this only surfaces success/failure via [ApiException] and returns
  /// void; the caller navigates to Routes.otp with the entered email once
  /// this completes. Name became required backend-side 2026-08-07 so Home
  /// can greet the investor by name instead of falling back to their
  /// email — split from one `fullName` field into
  /// firstName/middleName?/lastName 2026-08-19 so BVN/NIN verification has a
  /// real first/last to compare against the registry's own name fields.
  ///
  /// [phone] added 2026-08-28 (BR-3, SHARED-CHANGES.md S-2) once the backend
  /// gained the field, made REQUIRED 2026-09-01 (product-owner ruling, both
  /// sides) — mirrors Kudimata-Securities-Backend's `SignupDto.phone`,
  /// which is no longer optional either. Always sent now; there is no
  /// longer an "omit it" path.
  ///
  /// CONTRACT (2026-08-29, once sign_up_screen.dart's phone field gained a
  /// 186-country picker instead of a hardcoded `+234`): the caller is
  /// expected to always pass full E.164 (a leading `+` plus the picked
  /// country's dial code), built client-side by `composePhoneE164`
  /// (screens/onboarding/_pickers.dart) — not a bare local number. The
  /// server's `normalizePhone()` (src/common/phone.ts) trusts a leading `+`
  /// as carrying its own country code and validates it as generic E.164 for
  /// any country; it keeps a separate Nigeria-only tolerant fallback
  /// (`0803…`, `803…`, `234803…`, no leading `+`) only for callers with no
  /// explicit country context. Not format-validated here either way: that
  /// function is the one place that canonicalises the value, so duplicating
  /// a shape check here would only risk rejecting something the backend
  /// would have accepted. Two error paths a caller should expect: 400
  /// `INVALID_PHONE` (unparseable) and 409 `PHONE_ALREADY_REGISTERED`
  /// (already on another account) — both surface as the usual
  /// [ApiException] and are not caught here.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    String? middleName,
    required String lastName,
    required String phone,
  }) async {
    await _client.post('/auth/signup', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      if (middleName != null && middleName.isNotEmpty) 'middleName': middleName,
      'lastName': lastName,
      'phone': phone,
    });
  }

  /// Mirrors the OTP screen's Verify action. POST /auth/verify-email-otp
  /// {email, code} -> AuthSession (with tokens) — completes sign-up's
  /// email-verification step. See [AuthTokens] for the two fields parsed
  /// out of the response.
  Future<AuthTokens> verifyEmailOtp({required String email, required String code}) async {
    final response = await _client.post(
      '/auth/verify-email-otp',
      data: {'email': email, 'code': code},
    );
    final body = response.data as Map<String, dynamic>;
    return AuthTokens(
      accessToken: body['accessToken'] as String? ?? '',
      refreshToken: body['refreshToken'] as String?,
    );
  }

  /// Mirrors the log-in screen's email+password form (log_in_screen.dart) —
  /// the returning-investor path for a device with no valid local session
  /// (signed out, or a fresh device that has never signed in here). POST
  /// /auth/login {email, password} -> AuthSessionWithTokens | EmailOtp per
  /// Kudimata-Securities-Backend src/auth/auth.service.ts's `login()`: a
  /// normal session unless the account's carried-forward `stepUpAuthEnabled`
  /// preference is on, in which case the backend issues a `step_up` EmailOtp
  /// instead and withholds tokens until that code is redeemed — see
  /// [LoginResult] for how the caller tells the two apart. A wrong
  /// email/password or a suspended account surfaces as the usual
  /// [ApiException] (INVALID_CREDENTIALS / ACCOUNT_SUSPENDED) and is not
  /// caught here.
  Future<LoginResult> login({required String email, required String password}) async {
    final response = await _client.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final body = response.data as Map<String, dynamic>;
    final accessToken = body['accessToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      // No tokens in the response body -> this was the EmailOtp
      // step-up-challenge shape, not a session.
      return const LoginResult.stepUp();
    }
    return LoginResult.session(AuthTokens(
      accessToken: accessToken,
      refreshToken: body['refreshToken'] as String?,
    ));
  }

  /// Mirrors the OTP screen's Resend action. POST /email-otps/resend
  /// {email, purpose} -> EmailOtp — re-dispatches a fresh code. [purpose] is
  /// one of registry.json's EmailOtp resource's frozen `purpose` enum values
  /// (signup_verify | password_reset | step_up); defaults to the sign-up
  /// verification flow, the only caller today.
  Future<void> resendOtp({required String email, String purpose = 'signup_verify'}) async {
    await _client.post('/email-otps/resend', data: {'email': email, 'purpose': purpose});
  }

  /// Mirrors the account-security screen's "Two-factor authentication"
  /// KSwitch. PATCH /auth/step-up-preference {enabled} — registry.json's
  /// response shape is the bespoke `{stepUpAuthEnabled}`, not a full
  /// AuthSession, so this parses just that field and returns it, letting the
  /// caller reflect the server's authoritative value rather than assuming
  /// the request round-tripped the value unchanged.
  ///
  /// When true, login from a new/untrusted device requires an additional
  /// email-OTP step-up challenge (reusing the existing EmailOtp mechanism)
  /// before a full AuthSession is issued.
  ///
  /// Note: registry.json has no GET endpoint to read the current
  /// stepUpAuthEnabled value, so callers cannot fetch the preference on
  /// screen load — only this PATCH's response reflects server state.
  Future<bool> setStepUpAuth(bool enabled) async {
    final response = await _client.patch('/auth/step-up-preference', data: {
      'enabled': enabled,
    });
    return response.data['stepUpAuthEnabled'] as bool;
  }

  /// Backs the reset-passcode screen's first step (lib/screens/onboarding/
  /// reset_passcode_screen.dart). Despite that screen's name, the backend
  /// concept behind it is a real account PASSWORD reset — see that file's
  /// header for the reconciliation note (conventions.md: the app-local PIN
  /// is client-only and never sent to the server; registry.json has no
  /// passcode-reset endpoint, only a password one). POST
  /// /auth/request-password-reset {email} -> EmailOtp (registry.json,
  /// AuthSession resource) — issues the reset code by email; the screen
  /// doesn't need the returned EmailOtp fields, just that the call succeeded.
  Future<void> requestPasswordReset(String email) async {
    await _client.post('/auth/request-password-reset', data: {'email': email});
  }

  /// Backs the reset-passcode screen's second step. POST /auth/reset-password
  /// {email, code, newPassword} -> 204 No Content — NOT on the frozen
  /// registry.json contract; added by the backend team as the necessary
  /// completion of [requestPasswordReset] (a reset flow that issues a code
  /// but can never redeem it is a dead end, not a smaller version of the
  /// feature). Confirmed against Kudimata-Securities-Backend
  /// src/auth/auth.controller.ts (`resetPassword`) and
  /// src/auth/dto/reset-password.dto.ts, which fix this exact body shape
  /// (`email`, 6-char `code`, `newPassword` min length 8) and its
  /// 204-No-Content response. [code] redeems the OTP [requestPasswordReset]
  /// emailed to [email]; a wrong/expired code or invalid password surfaces
  /// as the usual ApiException.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.post('/auth/reset-password', data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }
}
