// The ONE definition of what makes a password acceptable, on the client.
//
// R-43 (docs/redesign/DECISIONS.md, 2026-08-29): at least 8 characters, one
// number and one special character.
//
// This file exists because the rule was changed on the server and in the
// sign-up screen on the same day, and the RESET-PASSWORD screen was missed. It
// went on accepting `Password1` — 8 characters with a number, no special
// character — which the server then rejected. The investor saw "Validation
// failed" and nothing else, on the screen they were using precisely because
// they could not get into their account.
//
// Two copies of a rule is two truths that drift, and this one drifted within
// hours of being written. Every screen that sets a password reads from here,
// and the backend's own `isStrongPassword` in
// `Kudimata-Securities-Backend/src/common/password-policy.ts` is the matching
// definition on the other side of the wire — keep them in step.
library;

/// Explicit ASCII special-character class, matching the backend's exactly. A
/// deliberate list rather than "not alphanumeric": that would count a space,
/// an accented letter or an emoji, and the two sides would disagree about
/// which of those pass.
final RegExp kPasswordSpecialPattern =
    RegExp(r'''[ !"#$%&'()*+,\-./:;<=>?@[\]^_`{|}~]''');

final RegExp _digit = RegExp(r'[0-9]');

/// Minimum length, per R-43.
const int kPasswordMinLength = 8;

bool passwordLongEnough(String value) => value.length >= kPasswordMinLength;

bool passwordHasNumberAndSpecial(String value) =>
    _digit.hasMatch(value) && kPasswordSpecialPattern.hasMatch(value);

bool passwordAcceptable(String value) =>
    passwordLongEnough(value) && passwordHasNumberAndSpecial(value);

/// The rule as the investor is told it — one wording, so a helper line under a
/// field cannot promise something different from what the field enforces.
const String kPasswordRuleLabel =
    'At least 8 characters, with a number and a special character';
