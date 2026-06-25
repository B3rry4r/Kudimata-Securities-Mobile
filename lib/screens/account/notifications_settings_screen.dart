// Stage 9 — Notifications settings (pushed). Grouped KSwitch lists by channel.
// Mirrors `Notifications` in settings-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  // Each group → ordered (channel, on) toggles. SEAM: real preference store
  // plugs in here.
  final List<(String eyebrow, List<(String, bool)> rows)> _groups = [
    ('Orders', [('Push', true), ('Email', true), ('SMS', false)]),
    ('Price alerts', [('Push', true), ('Email', false)]),
    ('Account', [('Push', true), ('Email', true), ('SMS', true)]),
  ];

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var g = 0; g < _groups.length; g++) ...[
            if (g > 0) const SizedBox(height: 24),
            KEyebrow(_groups[g].$1),
            const SizedBox(height: 10),
            KAccountCard(
              children: [
                for (var r = 0; r < _groups[g].$2.length; r++)
                  _ToggleRow(
                    label: _groups[g].$2[r].$1,
                    checked: _groups[g].$2[r].$2,
                    first: r == 0,
                    onChanged: (v) => setState(
                        () => _groups[g].$2[r] = (_groups[g].$2[r].$1, v)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.checked,
    required this.first,
    required this.onChanged,
  });
  final String label;
  final bool checked;
  final bool first;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : const BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.body(color: KColor.ink))),
          KSwitch(checked: checked, onChanged: onChanged),
        ],
      ),
    );
  }
}
