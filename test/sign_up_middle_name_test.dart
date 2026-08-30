// Regression test for the 2026-08-30 middle-name addition to sign-up (a
// product-owner request, via a colleague's dogfooding — "we should have a
// space for middle name"): the field must be genuinely optional. See
// sign_up_screen.dart's file header for why it exists at all despite the
// canvas (#s03) drawing no such field, and AuthRepository.signUp's doc
// comment for the wire contract.
//
// Two things this asserts, both load-bearing per the product owner's own
// words ("watch out validation should not be blocked please!"):
//
//   1. Leaving Middle name blank must NOT block the name step's Continue —
//      driven through the real Continue button, not by inspecting
//      `_firstNameValid`/`_lastNameValid` directly.
//   2. An empty middle name must be OMITTED from the POST /auth/signup body
//      entirely — not sent as `''` — since a naive DTO validator can treat
//      an empty string differently from an absent key. Captured via a
//      dedicated adapter rather than assuming AuthRepository.signUp's
//      internals.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/onboarding/otp_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

/// Captures the POST /auth/signup request body; answers 200 to everything
/// (sign_up_screen.dart calls nothing else before handing off to
/// otp_screen.dart, which itself makes no call in initState).
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastSignupBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/signup' && requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      lastSignupBody = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Bounded polling — same shape confirm_passcode_busy_state_test.dart's
/// helper of the same name uses: this app has periodic timers elsewhere
/// that never let `pumpAndSettle` return.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  } while (DateTime.now().isBefore(deadline));
  fail('Timed out after ${timeout.inSeconds}s waiting for $what');
}

Future<_CapturingAdapter> _mount(WidgetTester tester) async {
  // A phone-shaped surface — see gated_back_button_test.dart's identical
  // fix for why flutter_test's ~800×600 desktop-shaped default overflows
  // this exact (now three-KInput-tall) name step.
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final adapter = _CapturingAdapter();
  final apiClient = ApiClient()..dio.httpClientAdapter = adapter;
  final state = AppState()..apiClient = apiClient;
  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
    ),
  );
  router.go(Routes.signup);
  await tester.pump();
  // Long enough to clear GoRouter's page-transition animation from whatever
  // the router's initial location is — found live: at 50ms the incoming
  // route was still mid-slide, which put the Continue button's hit-test
  // target hundreds of logical pixels off whatever the FINAL screen
  // geometry would be, and a tap there landed on nothing.
  await tester.pump(const Duration(milliseconds: 700));
  return adapter;
}

/// Drives the wizard from the name step through to a submitted signup.
/// [middleName] is left untouched (blank) when null.
Future<void> _fillAndSubmit(WidgetTester tester, {String? middleName}) async {
  // Step 1 — name (#s03). Field order in the Column: first, middle, last.
  final nameFields = find.byType(TextField);
  await tester.enterText(nameFields.at(0), 'Adebayo');
  if (middleName != null) {
    await tester.enterText(nameFields.at(1), middleName);
  }
  await tester.enterText(nameFields.at(2), 'Okonkwo');
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  // Step 2 — contact (#s03b): only email is required.
  expect(find.text('How do we reach you?'), findsOneWidget,
      reason: 'an empty middle name must not have blocked step 1\'s Continue');
  final contactFields = find.byType(TextField);
  await tester.enterText(contactFields.at(0), 'adebayo@example.com');
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  // Step 3 — password (#s03p).
  expect(find.text('Create a password'), findsOneWidget);
  final passwordFields = find.byType(TextField);
  await tester.enterText(passwordFields.at(0), 'Passw0rd!');
  await tester.enterText(passwordFields.at(1), 'Passw0rd!');
  await tester.pump();
  await tester.tap(find.text('Create account'));
  await tester.pump();
}

void main() {
  testWidgets(
    'an empty middle name does not block Continue, and the signup request '
    'omits the key entirely rather than sending an empty string',
    (tester) async {
      final adapter = await _mount(tester);
      await _fillAndSubmit(tester);

      await pumpUntil(
        tester,
        () => find.byType(OtpScreen).evaluate().isNotEmpty,
        'signup with a blank middle name to succeed and reach OTP',
      );

      final body = adapter.lastSignupBody;
      expect(body, isNotNull, reason: 'POST /auth/signup was never sent');
      expect(body!['firstName'], 'Adebayo');
      expect(body['lastName'], 'Okonkwo');
      expect(
        body.containsKey('middleName'),
        isFalse,
        reason: 'an empty middle name must be OMITTED, not sent as "" — a '
            '@IsString() DTO field with no @IsOptional() on the backend '
            'would treat those differently',
      );
    },
  );

  testWidgets(
    'a filled-in middle name IS sent, trimmed',
    (tester) async {
      final adapter = await _mount(tester);
      await _fillAndSubmit(tester, middleName: '  Chinedu  ');

      await pumpUntil(
        tester,
        () => find.byType(OtpScreen).evaluate().isNotEmpty,
        'signup with a middle name to succeed and reach OTP',
      );

      expect(adapter.lastSignupBody?['middleName'], 'Chinedu');
    },
  );
}
