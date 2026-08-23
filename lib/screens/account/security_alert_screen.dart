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
      appBar: KDetailHeader(title: 'Security alert'),
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
                primary: KButton(
                  label: 'Freeze my account and sign that device out',
                  variant: KButtonVariant.destructive,
                  loading: _freezing,
                  onPressed: _freezing ? null : _freezeAndSignOut,
                ),
                secondary: KButton(
                  label: 'That was me',
                  variant: KButtonVariant.secondary,
                  onPressed: _freezing ? null : () => Navigator.of(context).pop(),
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
