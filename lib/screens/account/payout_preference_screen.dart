// Account → Payout preference. NEW screen, 2026-09-04.
//
// The owner's addition to the SEC's No Objection condition 1: "DCS is the
// default, but the investor can opt out LATER too — not only during
// onboarding." KYC step 5 (bank_dcs_screen.dart) asks the question once,
// during onboarding; this screen is the same question for the rest of the
// account's life.
//
// It renders [PayoutChoice] — the SAME component the KYC step renders, not a
// second copy of it. The copy, the ordering, the "Recommended" pill, and the
// opt-out confirmation sheet all live in lib/screens/shared/payout_choice.dart
// and are therefore identical on both surfaces by construction. See that
// file's header for the three layers that make an opt-out explicit.
//
// Everything on this screen is real server state: GET
// /users/me/payout-preference supplies the preference, the DCS mandate
// account it would actually pay into, when the investor chose, and the
// server's own `needsDcsAccount` flag. Nothing is derived locally — the app
// must never disagree with the backend about where money goes.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/payout_choice.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'account_widgets.dart';

class PayoutPreferenceScreen extends StatefulWidget {
  const PayoutPreferenceScreen({super.key});

  @override
  State<PayoutPreferenceScreen> createState() => _PayoutPreferenceScreenState();
}

class _PayoutPreferenceScreenState extends State<PayoutPreferenceScreen> {
  late final _repo = UserRepository(AppScope.read(context).apiClient);
  late Future<PayoutPreferenceState> _future = _repo.payoutPreference();

  PayoutPreferenceState? _state;
  bool _saving = false;
  String? _error;

  void _reload() {
    setState(() {
      _state = null;
      _error = null;
      _future = _repo.payoutPreference();
    });
  }

  /// See bank_dcs_screen.dart's `_setPayout` — the same rule, deliberately the
  /// same shape: leaving DCS goes through [confirmDcsOptOut] first, and
  /// `acknowledgedDcsOptOut: true` is sent only when that returned true. A
  /// declined or dismissed sheet changes nothing at all.
  Future<void> _change(String preference) async {
    final current = _state;
    if (current == null || _saving || preference == current.preference) return;
    if (preference == kPayoutWallet) {
      final confirmed = await confirmDcsOptOut(context);
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _repo.setPayoutPreference(
        preference,
        acknowledgedDcsOptOut: preference == kPayoutWallet ? true : null,
      );
      if (!mounted) return;
      setState(() => _state = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      // The selection is left showing what the SERVER still believes, not
      // what was attempted — this screen must never claim a payout route
      // that was not saved.
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save your payout choice. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Payout preference',
      child: FutureBuilder<PayoutPreferenceState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: KLoadingView(),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: KErrorView(onPrimary: _reload),
            );
          }
          final state = _state ??= snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'When you sell, this is where the money goes.',
                style: KType.body(color: KColor.ink2).copyWith(fontSize: 17, height: 26 / 17),
              ),
              const SizedBox(height: 20),
              PayoutChoice(
                value: state.preference,
                onChanged: _change,
                dcsAccountLabel: state.dcsAccountLabel,
                needsDcsAccount: state.needsDcsAccount,
                enabled: !_saving,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: KType.body(color: KColor.loss)),
              ],
              const SizedBox(height: 20),
              // Honest about WHY they are on what they are on. `setAt == null`
              // means they have never chosen and are on Direct Cash Settlement
              // because it is the default — saying "you chose this" there would
              // be a lie the server itself keeps the evidence against.
              Text(
                state.setAt == null
                    ? 'Direct Cash Settlement is the default for every investor. You have not '
                        'changed this.'
                    : 'You chose this on ${_formatChoiceDate(state.setAt!)}.',
                style: KType.data(color: KColor.ink3),
              ),
              const SizedBox(height: 16),
              KAccountRow(
                icon: 'card',
                iconTint: KColor.indicatorTint,
                title: 'Bank accounts & DCS',
                sub: state.dcsAccountLabel ?? 'No DCS account yet',
                standalone: true,
                onTap: () async {
                  await context.push(Routes.acctBanks);
                  // The mandate account may have changed while they were in
                  // there — re-read rather than showing a stale account label
                  // next to a live preference.
                  if (mounted) _reload();
                },
                right: const KRowChevron(),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "4 September 2026". Returns null-safe plain text for an unparseable value
/// rather than throwing on a timestamp shape this build does not expect.
String _formatChoiceDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return 'a previous visit';
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
}
