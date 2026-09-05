// The opt-out has to be an ACT, not a tap — Nigerian SEC No Objection
// condition 1 (2026-09-04):
//
//   "The Company is required to configure Direct Cash Settlement (DCS) as the
//   default payout option for investors. Where an investor elects to receive
//   wallet credits instead, the application should require the investor to
//   explicitly opt out of DCS and select the alternative payout option."
//
// The server is the backstop: PATCH /users/me/payout-preference refuses a
// wallet-credit request that does not carry `acknowledgedDcsOptOut: true`
// (422 DCS_OPT_OUT_NOT_ACKNOWLEDGED). This file guards the CLIENT half — that
// tapping "wallet" alone never writes anything, that the acknowledgement is
// only ever sent after a confirmed sheet, and that DCS is what an investor
// lands on when they do nothing.
//
// It drives the real screen through the real router and inspects the real
// outbound HTTP requests. A recording adapter rather than a mocked repository:
// what the app SENDS is the thing under test, and a mocked repository would
// let a screen pass this file while sending something else on the wire.
//
//   flutter test test/dcs_opt_out_is_explicit_test.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

/// Wraps [MockApiAdapter] and records every request that goes past it, so a
/// test can assert on what the app actually put on the wire — including the
/// requests it did NOT make.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._inner);
  final HttpClientAdapter _inner;

  final List<({String method, String path, Object? body})> calls = [];

  /// The current server-side preference this fake holds. A PATCH updates it,
  /// so a screen re-reading after a write sees what it wrote — and a screen
  /// that never wrote sees DCS still in force.
  String preference = 'dcs';

  List<({String method, String path, Object? body})> get payoutWrites => calls
      .where((c) => c.method == 'PATCH' && c.path == '/users/me/payout-preference')
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

    if (options.path == '/users/me/payout-preference') {
      if (options.method == 'PATCH') {
        final body = (options.data as Map).cast<String, dynamic>();
        // The real server's rule, reproduced: a wallet-credit write without a
        // true acknowledgement is refused. A screen that skipped the
        // confirmation sheet fails here the same way it would in production.
        if (body['preference'] == 'wallet' && body['acknowledgedDcsOptOut'] != true) {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'DCS_OPT_OUT_NOT_ACKNOWLEDGED',
                'message': 'You must explicitly opt out of Direct Cash Settlement.',
              }
            }),
            422,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            },
          );
        }
        preference = body['preference'] as String;
      }
      return ResponseBody.fromString(
        jsonEncode({
          'preference': preference,
          'setAt': preference == 'dcs' ? null : '2026-09-04T10:00:00.000Z',
          'dcsBankAccountId': 'BA1',
          'dcsAccountLabel': 'GTBank ••••6789',
          'needsDcsAccount': false,
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

Future<(GoRouter, _RecordingAdapter)> _mount(WidgetTester tester, String route) async {
  _mockPlatformChannels();
  final adapter = _RecordingAdapter(MockApiAdapter());
  final apiClient = ApiClient()..dio.httpClientAdapter = adapter;
  final state = AppState()
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
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
  router.go(route);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return (router, adapter);
}

void main() {
  // KYC step 5 deliberately does NOT carry the choice any more (owner's
  // ruling, 2026-09-05): that step STATES the default, and the opt-out lives
  // in Account only. Its own assertion is at the bottom of this file — it must
  // show the DCS statement and must NOT offer a way to leave it, because an
  // investor who has not yet finished verifying has no balance to settle and
  // no reason to be asked a settlement question.
  for (final (label, route) in <(String, String)>[
    ('Account → Payout preference', Routes.acctPayoutPreference),
  ]) {
    group(label, () {
      testWidgets('opens on Direct Cash Settlement, and writes nothing by opening', (tester) async {
        final (_, adapter) = await _mount(tester, route);

        expect(find.text('Pay it to my bank'), findsOneWidget);
        expect(find.text('Hold it in my Kudimata wallet'), findsOneWidget);
        // "Recommended" sits on the DCS option — the regulator's default is
        // visibly the default, not just the one that happens to be first.
        // KStatusPill upper-cases its label.
        expect(find.text('RECOMMENDED'), findsOneWidget);
        // Merely arriving on the screen must not record an election. An
        // investor who has never chosen is on DCS BY DEFAULT, and
        // payoutPreferenceSetAt has to stay null so the server can still tell
        // those two states apart.
        expect(adapter.payoutWrites, isEmpty);
      });

      testWidgets('tapping wallet credit asks first, and abandoning the sheet changes nothing',
          (tester) async {
        final (_, adapter) = await _mount(tester, route);

        await tester.tap(find.text('Hold it in my Kudimata wallet'));
        await tester.pumpAndSettle();

        // Layer 2 of the explicit opt-out (payout_choice.dart): a sheet that
        // says what is being given up, whose PRIMARY action is to stay on DCS.
        expect(find.text('Turn off Direct Cash Settlement?'), findsOneWidget);
        expect(adapter.payoutWrites, isEmpty,
            reason: 'the sheet had not been answered yet — nothing may have been written');

        await tester.tap(find.text('Keep Direct Cash Settlement'));
        await tester.pumpAndSettle();

        expect(adapter.payoutWrites, isEmpty,
            reason: 'declining the opt-out must leave the investor on DCS, silently and completely');
      });

      testWidgets('confirming the sheet is what sends the acknowledgement — and only then',
          (tester) async {
        final (_, adapter) = await _mount(tester, route);

        await tester.tap(find.text('Hold it in my Kudimata wallet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Turn it off and use my wallet'));
        await tester.pumpAndSettle();

        expect(adapter.payoutWrites, hasLength(1));
        expect(
          (adapter.payoutWrites.single.body as Map).cast<String, dynamic>(),
          {'preference': 'wallet', 'acknowledgedDcsOptOut': true},
          reason: 'the acknowledgement flag is the whole mechanism — without it the server '
              'refuses the write with DCS_OPT_OUT_NOT_ACKNOWLEDGED',
        );
        expect(adapter.preference, 'wallet');
      });

      testWidgets('switching BACK to DCS needs no ceremony and sends no acknowledgement',
          (tester) async {
        final (_, adapter) = await _mount(tester, route);

        // Get onto wallet credit the only way the app allows, then clear the
        // record so the assertion below is about the RETURN trip alone.
        await tester.tap(find.text('Hold it in my Kudimata wallet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Turn it off and use my wallet'));
        await tester.pumpAndSettle();
        adapter.calls.clear();

        await tester.tap(find.text('Pay it to my bank'));
        await tester.pumpAndSettle();

        // No sheet — returning to the default is not an opt-out.
        expect(find.text('Turn off Direct Cash Settlement?'), findsNothing);
        expect(adapter.payoutWrites, hasLength(1));
        expect(
          (adapter.payoutWrites.single.body as Map).cast<String, dynamic>(),
          {'preference': 'dcs'},
          reason: 'the server rejects acknowledgedDcsOptOut alongside dcs as self-contradicting',
        );
        expect(adapter.preference, 'dcs');
      });
    });
  }

  group('KYC step 5 (Bank & DCS)', () {
    testWidgets('states that DCS is the default and offers no way out of it', (tester) async {
      final (_, adapter) = await _mount(tester, Routes.kycBankDcs);

      // The regulator's condition is that DCS be the DEFAULT. This step is
      // where the investor is told so.
      expect(find.text('DIRECT CASH SETTLEMENT'), findsOneWidget);
      expect(
        find.textContaining('That is the default for every investor'),
        findsOneWidget,
        reason: 'the investor must be told DCS is the default at the step that '
            'collects the account it settles to',
      );

      // And it must not ask. The choice belongs in Account.
      expect(find.text('Pay it to my bank'), findsNothing);
      expect(find.text('Hold it in my Kudimata wallet'), findsNothing);

      // Opening the step writes no preference at all — an investor who backs
      // out here is still on the default, not on something this screen saved.
      expect(
        adapter.calls.where((c) => c.path.contains('payout-preference')),
        isEmpty,
        reason: 'KYC step 5 no longer reads or writes the payout preference',
      );
    });
  });
}
