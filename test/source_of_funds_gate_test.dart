// Occupation and source of funds actually GATE, and the dropdown did not
// weaken either of them.
//
//   * Source of funds — Nigerian SEC No Objection condition 2 (2026-09-04):
//     "a dedicated 'Source of Funds' field within the onboarding questionnaire
//     to support appropriate investor profiling and the required AML/CFT due
//     diligence."
//   * Occupation — SEC (Capital Market Operators) AML/CFT/CPF Regulations 2022,
//     reg 50(3)(e): "verification of employment or public position held".
//     Added 2026-09-05, on the SAME screen — NOT as a ninth KYC step.
//
// "Required, not optional" is easy to claim and easy to ship without. This
// file drives the real screen and asserts the things that make the difference
// between a field and a gate:
//
//   1. Continue with nothing answered does not advance and does not write.
//   2. Either half missing does not advance and does not write — including an
//      occupation that is only whitespace, and a "Something else" with no
//      description (an unexplained "other" is the absence of an AML answer
//      wearing the shape of one).
//   3. A real answer PATCHes the wire values the backend defines — both fields
//      in ONE request, through the endpoint that already carried source of
//      funds — and only then moves on.
//
// The nine options moved BEHIND a picker sheet on 2026-09-05 (owner
// instruction: nine visible options is too tall a list to sit as radios), so
// these cases open the sheet rather than tapping an inline row. That is the
// point of driving the real screen: had the sheet not opened, or not carried
// the nine options, these fail.
//
//   flutter test test/source_of_funds_gate_test.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/kyc/source_of_funds_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

/// Records outbound requests and serves a draft whose `sourceOfFunds` and
/// `occupation` are both null — the state a real investor is in the first time
/// they reach this step. [MockApiAdapter]'s own draft has both answered (it
/// represents a much later point in the flow), which is exactly the state this
/// file must NOT start from.
class _UnansweredDraftAdapter implements HttpClientAdapter {
  _UnansweredDraftAdapter(this._inner);
  final HttpClientAdapter _inner;

  final List<({String method, String path, Object? body})> calls = [];

  List<({String method, String path, Object? body})> get draftPatches => calls
      .where((c) => c.method == 'PATCH' && c.path == '/kyc-submissions/draft')
      .toList();

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add((method: options.method, path: options.path, body: options.data));

    if (options.path == '/kyc-submissions/draft' && options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'KYC1',
          'userId': 'U1',
          'status': 'draft',
          'chn': '1234567890',
          'pepSelfDeclared': false,
          'sourceOfFunds': null,
          'sourceOfFundsOther': null,
          'occupation': null,
          'documents': const [],
          'submittedAt': '2026-09-04T09:00:00.000Z',
          'attemptCount': 0,
          'maxAttempts': 5,
          'canRetry': false,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }
}

void _mockPlatformChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => switch (call.method) {
      'read' => null,
      'readAll' => <String, String>{},
      'containsKey' => false,
      _ => null,
    },
  );
}

Future<(GoRouter, _UnansweredDraftAdapter)> _mount(WidgetTester tester) async {
  _mockPlatformChannels();
  final adapter = _UnansweredDraftAdapter(MockApiAdapter());
  final apiClient = ApiClient()..dio.httpClientAdapter = adapter;
  final state = AppState()
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
    ..kycSubmitted = false
    ..kycApproved = false
    ..apiClient = apiClient
    ..kycForm = KycFormState();
  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  router.go(Routes.kycSourceOfFunds);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return (router, adapter);
}

/// Opens the source-of-funds picker sheet and taps one option by its label.
/// Everything the investor does, in the order they do it — the collapsed
/// select is tapped, the sheet settles, the option is chosen.
Future<void> _pickSource(WidgetTester tester, String label) async {
  await tester.tap(find.text('Select a source'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _enterOccupation(WidgetTester tester, String value) async {
  await tester.enterText(find.widgetWithText(TextField, 'e.g. Secondary school teacher'), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the nine options are the backend enum, in the app, unedited', (tester) async {
    await _mount(tester);
    // A screen must never invent a wire value: every label offered comes from
    // kSourceOfFundsOptions (lib/data/), which mirrors the backend's
    // SourceOfFunds enum. Nine, not eight, not ten.
    expect(kSourceOfFundsOptions, hasLength(9));

    // Behind the picker now, not inline — but ALL NINE must still be reachable.
    // A dropdown that quietly offers seven of them is the failure this asserts
    // against.
    await tester.tap(find.text('Select a source'));
    await tester.pumpAndSettle();
    for (final option in kSourceOfFundsOptions) {
      expect(find.text(option.label), findsOneWidget,
          reason: '${option.code} is a lawful answer the server accepts but the picker never offers');
    }
  });

  testWidgets('the collapsed select shows the chosen option, not a wire code', (tester) async {
    await _mount(tester);
    expect(find.text('Select a source'), findsOneWidget,
        reason: 'an unanswered select must read as unanswered');

    await _pickSource(tester, 'Inheritance');

    expect(find.text('Inheritance'), findsOneWidget);
    expect(find.text('Select a source'), findsNothing);
    expect(find.text('inheritance'), findsNothing,
        reason: 'the investor is shown the label; the wire code stays in lib/data/');
  });

  testWidgets('Continue with nothing answered does not advance and writes nothing', (tester) async {
    final (router, adapter) = await _mount(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(SourceOfFundsScreen), findsOneWidget,
        reason: 'the step must not be walked past without answers');
    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycSourceOfFunds);
    expect(adapter.draftPatches, isEmpty);
    // Both refusals name themselves — a disabled-feeling button that says
    // nothing is worse than a refusal that explains itself.
    expect(find.text('Pick your source of funds to continue.'), findsOneWidget);
    expect(find.text('Tell us what you do for a living.'), findsOneWidget);
  });

  testWidgets('a source of funds with no occupation does not advance and writes nothing',
      (tester) async {
    final (router, adapter) = await _mount(tester);

    await _pickSource(tester, 'Savings');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycSourceOfFunds);
    expect(adapter.draftPatches, isEmpty,
        reason: 'half an answer must not be written — the server refuses to finalize on it');
    expect(find.text('Tell us what you do for a living.'), findsOneWidget);
  });

  testWidgets('a whitespace-only occupation is the same refusal as an empty one', (tester) async {
    // A column holding '   ' passes any non-null check and tells a compliance
    // officer nothing. The server treats it as absent; so does this screen,
    // rather than sending a request it knows will be refused.
    final (_, adapter) = await _mount(tester);

    await _pickSource(tester, 'Savings');
    await _enterOccupation(tester, '   ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(adapter.draftPatches, isEmpty);
    expect(find.text('Tell us what you do for a living.'), findsOneWidget);
  });

  testWidgets('an occupation with no source of funds does not advance and writes nothing',
      (tester) async {
    final (router, adapter) = await _mount(tester);

    await _enterOccupation(tester, 'Pharmacist');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycSourceOfFunds);
    expect(adapter.draftPatches, isEmpty);
    expect(find.text('Pick your source of funds to continue.'), findsOneWidget);
  });

  testWidgets('"Something else" with no description does not advance and writes nothing',
      (tester) async {
    final (router, adapter) = await _mount(tester);

    await _pickSource(tester, 'Something else');
    await _enterOccupation(tester, 'Trader');
    // Picking it reveals the description field — it is not a hidden
    // requirement the investor discovers by being refused.
    expect(find.widgetWithText(TextField, 'e.g. Proceeds from a matured cooperative contribution'),
        findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycSourceOfFunds);
    expect(adapter.draftPatches, isEmpty);
    expect(find.text('Describe where your money comes from.'), findsOneWidget);
  });

  testWidgets('a real answer PATCHes both wire values in ONE request and moves on', (tester) async {
    final (router, adapter) = await _mount(tester);

    await _pickSource(tester, 'Inheritance');
    await _enterOccupation(tester, '  Pharmacist  ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(adapter.draftPatches, hasLength(1),
        reason: 'both fields are collected on one screen and travel in one PATCH — '
            'no second endpoint was added for occupation');
    expect(
      (adapter.draftPatches.single.body as Map).cast<String, dynamic>(),
      {'sourceOfFunds': 'inheritance', 'occupation': 'Pharmacist'},
      reason: 'sourceOfFundsOther is only sent for "other" — the server rejects it otherwise; '
          'occupation is trimmed so what is shown on resume is what was stored',
    );
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        isNot(Routes.kycSourceOfFunds));
  });

  testWidgets('"Something else" WITH a description sends all three fields', (tester) async {
    final (_, adapter) = await _mount(tester);

    await _pickSource(tester, 'Something else');
    await _enterOccupation(tester, 'Cooperative treasurer');
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Proceeds from a matured cooperative contribution'),
      'Matured cooperative contribution',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(adapter.draftPatches, hasLength(1));
    expect(
      (adapter.draftPatches.single.body as Map).cast<String, dynamic>(),
      {
        'sourceOfFunds': 'other',
        'sourceOfFundsOther': 'Matured cooperative contribution',
        'occupation': 'Cooperative treasurer',
      },
    );
  });

  testWidgets('occupation cannot be typed past the wire bound', (tester) async {
    // Bounded free text, not unbounded free text. The cap is the backend's own
    // OCCUPATION_MAX_LENGTH, mirrored in lib/data/ — enforced while typing so
    // the investor cannot build a request the server will refuse.
    final (_, adapter) = await _mount(tester);

    await _pickSource(tester, 'Savings');
    await _enterOccupation(tester, 'a' * (kOccupationMaxLength + 50));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final sent = (adapter.draftPatches.single.body as Map)['occupation'] as String;
    expect(sent.length, kOccupationMaxLength);
  });
}
