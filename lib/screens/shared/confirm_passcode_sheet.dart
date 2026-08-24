// Shared "confirm your passcode" bottom sheet.
//
// Extracted from security_screen.dart (2026-08-24) so the withdraw flow can
// reuse the SAME sheet rather than growing a second copy — a forked
// passcode prompt is exactly the kind of duplicate that drifts out of sync
// with the real PasscodeStore hashing rules.
//
// Returns true via Navigator.pop only on a verified passcode; a dismissed
// sheet returns null, which every caller must treat as "not confirmed".
import 'package:flutter/material.dart';

import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/screens/onboarding/onboarding_scaffold.dart'
    show KPasscodeDots, KKeypad;

/// Shows the sheet and resolves true ONLY if the passcode was verified.
/// [title]/[message] let a caller say what is being authorised — money
/// leaving an account deserves different words from a settings change.
Future<bool> confirmPasscode(
  BuildContext context, {
  required PasscodeStore store,
  String title = 'Confirm your current passcode',
  String message = 'Enter your current passcode to continue.',
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KColor.bg,
    builder: (_) => ConfirmPasscodeSheet(store: store, title: title, message: message),
  );
  return ok == true;
}

class ConfirmPasscodeSheet extends StatefulWidget {
  const ConfirmPasscodeSheet({
    super.key,
    required this.store,
    this.title = 'Confirm your current passcode',
    this.message = 'Enter your current passcode to continue.',
  });
  final PasscodeStore store;
  final String title;
  final String message;

  @override
  State<ConfirmPasscodeSheet> createState() => _ConfirmPasscodeSheetState();
}

class _ConfirmPasscodeSheetState extends State<ConfirmPasscodeSheet> {
  String _code = '';
  bool _error = false;
  bool _checking = false;

  Future<void> _onKey(String k) async {
    if (_checking) return;
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        _error = false;
      } else if (_code.length < 6) {
        _code += k;
        _error = false;
      }
    });
    if (_code.length == 6) {
      setState(() => _checking = true);
      final ok = await widget.store.verifyPasscode(_code);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = true;
          _checking = false;
          _code = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.title, style: KType.section()),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 28),
            KPasscodeDots(filled: _code.length, error: _error),
            const SizedBox(height: 14),
            if (_error)
              Text(
                'Incorrect passcode',
                style: KType.body(color: KColor.loss, w: KWeight.medium),
              ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: KKeypad(onKey: _onKey),
            ),
          ],
        ),
      ),
    );
  }
}
