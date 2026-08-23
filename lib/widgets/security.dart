// SecurityAlert + FreezeConfirm (2026-08-22 "Soft Landing" — genuinely new,
// components/security/{SecurityAlert,FreezeConfirm}.jsx). The audit's P0:
// lead with what happened, then one obvious action — never a numbered list
// of manual steps. Sober rather than warm: this is the one place the
// illustration system stops being friendly.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'illustration.dart';

/// A device/location/time security alert with an immediate primary action
/// (screen 51 — "Freeze my account and sign that device out").
class KSecurityAlert extends StatelessWidget {
  const KSecurityAlert({
    super.key,
    this.title = "New sign-in on a device we don't recognise",
    this.device,
    this.location,
    this.when,
    required this.primary,
    this.secondary,
    this.fraudDesk,
  });

  final String title;
  final String? device;
  final String? location;
  final String? when;
  final Widget primary;
  final Widget? secondary;
  final String? fraudDesk;

  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.upper, style: KType.micro(color: KColor.ink3)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right, style: KType.data(color: KColor.ink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
        boxShadow: KShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const KIllustration('security-alert', role: KIlloRole.small),
          const SizedBox(height: 18),
          Text(title, style: KType.section()),
          const SizedBox(height: 12),
          if (device != null) _row('Device', device!),
          if (location != null) _row('Location', location!),
          if (when != null) _row('When', when!),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            primary,
            ?secondary,
          ]),
          if (fraudDesk != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: Text(fraudDesk!, style: KType.data(color: KColor.ink3)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Self-service freeze confirmation — reversible, and the copy says so
/// before the tap, since the whole point is the user can act without
/// waiting for staff (screens 50, 51, and the DCS-mandate withdraw at 65).
class KFreezeConfirm extends StatelessWidget {
  const KFreezeConfirm({
    super.key,
    this.title = 'Freeze your account?',
    this.effects = const [],
    required this.primary,
    this.secondary,
  });

  final String title;
  final List<String> effects;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: KType.title()),
        const SizedBox(height: 16),
        for (final e in effects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: KColor.ink3, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e, style: KType.body(color: KColor.ink2))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: primary),
          if (secondary != null) ...[const SizedBox(width: 10), Expanded(child: secondary!)],
        ]),
      ],
    );
  }
}
