// Security alert (screen 51, 2026-08-22 "Soft Landing" — audit P0). Reached
// from a push notification about an unrecognised sign-in, or from the
// Notifications list. Device/location/time here are placeholder example
// values: no real device-fingerprinting/new-device-detection feed exists on
// the backend yet (see docs/redesign/PLAN.md) — the login-alert EMAIL is
// real and already fires (AuthService.notifyLogin()), but it carries no
// device/location payload today for this screen to read. Both actions
// (freeze, dismiss) are fully real.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class SecurityAlertScreen extends StatefulWidget {
  const SecurityAlertScreen({super.key});

  @override
  State<SecurityAlertScreen> createState() => _SecurityAlertScreenState();
}

class _SecurityAlertScreenState extends State<SecurityAlertScreen> {
  late final _repo = UserRepository(AppScope.read(context).apiClient);
  bool _freezing = false;
  String? _error;

  Future<void> _freezeAndSignOut() async {
    setState(() {
      _freezing = true;
      _error = null;
    });
    try {
      await _repo.freeze();
      if (!mounted) return;
      await AppScope.read(context).forceSignOut();
      if (!mounted) return;
      context.go(Routes.login);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _freezing = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _freezing = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      // Canvas #s51's own header title is literally "Security" (the "51 ·
      // Security alert" caption above the phone frame is the gallery
      // label, not on-screen copy) — 2026-08-23 exactness pass.
      appBar: KDetailHeader(title: 'Security'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KSecurityAlert(
                device: 'Infinix Hot 30',
                location: 'Ibadan, Oyo',
                when: 'Today · 09:48',
                fraudDesk: 'Fraud desk · 0700 583 4626, 24 hours',
                // Full-width (the KButton default) — KSecurityAlert stacks
                // primary/secondary vertically, not side-by-side, precisely
                // because `primary`'s label below is too long to share a row
                // at any width (see security.dart's header comment on this).
                // Canvas footer says this button also "returns to 50", but
                // the only real freeze capability this app has
                // (UserRepository.freeze() / POST /users/me/freeze) revokes
                // EVERY session immediately, not just the flagged device's —
                // there's no narrower "sign out just that one device" API.
                // Landing back on an authenticated Security screen after
                // that call would be actively wrong, so this keeps its
                // existing, necessary real behaviour instead: freeze, force
                // sign this session out too, and go to login. Documented,
                // reviewed deviation, same reasoning as freeze_account_screen.dart.
                primary: KButton(
                  label: 'Freeze my account and sign that device out',
                  variant: KButtonVariant.destructive,
                  loading: _freezing,
                  onPressed: _freezing ? null : _freezeAndSignOut,
                ),
                secondary: KButton(
                  label: 'That was me',
                  variant: KButtonVariant.secondary,
                  // Canvas footer: "either action returns to 50" (Security)
                  // — go(), not pop(), since this screen's other real entry
                  // point is a push notification tap, which may not have
                  // Security anywhere on the stack to pop back to
                  // (2026-08-23 exactness pass). Routes.acctSecurity is a
                  // top-level GoRoute (not nested in a tab shell), so go()
                  // here is safe from any entry point.
                  onPressed: _freezing ? null : () => context.go(Routes.acctSecurity),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Freezing stops orders and withdrawals straight away. Your shares stay yours at the CSCS — nothing is sold.',
                style: KType.body(color: KColor.ink3),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: KType.body(color: KColor.loss)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
