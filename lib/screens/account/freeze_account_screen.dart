// Self-service account freeze (screen 50/51, 2026-08-22 "Soft Landing" —
// audit P0: "no self-service freeze exists, only admin-side suspend"). Calls
// the real, deployed POST /users/me/freeze (UserRepository.freeze()), which
// blocks new orders/withdrawals and revokes every session immediately.
// Reversible only by contacting support — there is no self-service unfreeze,
// so this screen never offers one.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/account/account_widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class FreezeAccountScreen extends StatefulWidget {
  const FreezeAccountScreen({super.key});

  @override
  State<FreezeAccountScreen> createState() => _FreezeAccountScreenState();
}

class _FreezeAccountScreenState extends State<FreezeAccountScreen> {
  late final _repo = UserRepository(AppScope.read(context).apiClient);
  bool _freezing = false;
  String? _error;

  Future<void> _freeze() async {
    setState(() {
      _freezing = true;
      _error = null;
    });
    try {
      await _repo.freeze();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: KColor.paper,
          title: Text('Your account is frozen', style: KType.cardTitle()),
          content: Text(
            'Orders and withdrawals are blocked immediately. Your shares stay yours at the CSCS — nothing is sold. Contact support to lift the freeze.',
            style: KType.body(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: KType.cardTitle(color: KColor.indicator)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Session is revoked server-side the moment freeze() returns — sign
      // the local session out too rather than leaving a dead access token
      // in memory, and land back at login (not Home, which the freeze just
      // made unusable for anything but browsing).
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
    return KAccountSubScaffold(
      title: 'Freeze account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KFreezeConfirm(
            title: 'Freeze your account?',
            effects: const [
              'Stops new orders and withdrawals immediately',
              'Your shares stay yours at the CSCS — nothing is sold',
              'Signs every device out, including this one',
              'You\'ll need to contact support to lift the freeze',
            ],
            primary: KButton(
              label: 'Freeze my account',
              variant: KButtonVariant.destructive,
              loading: _freezing,
              onPressed: _freezing ? null : _freeze,
            ),
            secondary: KButton(
              label: 'Cancel',
              variant: KButtonVariant.ghost,
              onPressed: _freezing ? null : () => Navigator.of(context).pop(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: KType.body(color: KColor.loss)),
          ],
        ],
      ),
    );
  }
}
