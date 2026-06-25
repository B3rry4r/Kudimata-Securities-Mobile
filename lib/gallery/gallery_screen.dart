// Stage 1 review gallery — renders every token and shared widget so the design
// system can be checked against the source before any screen is built. This file
// is scaffolding for review; it is not part of the shipped navigation.
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _nav = 'home';
  String _seg = 'buy';
  String _segPay = 'email';
  int _chip = 0;
  bool _check = true;
  bool _radio = true;
  bool _switch = true;
  KFileInfo? _file;

  static const List<double> _spark = [3, 4, 3.5, 5, 4.6, 6, 5.4, 7, 6.8, 8];
  static const List<double> _line = [12, 12.4, 12.1, 12.9, 12.6, 13.4, 13.1, 13.8, 13.5, 14.6, 14.2, 15.1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const KWordmark(size: 34),
            const SizedBox(height: 6),
            Text('Design system · Stage 1', style: KType.body(color: KColor.ink2)),
            const SizedBox(height: 28),

            // ── Colour ──
            _Section('Colour'),
            Wrap(spacing: 12, runSpacing: 12, children: const [
              _Swatch('paper', KColor.paper, border: true),
              _Swatch('bg', KColor.bg, border: true),
              _Swatch('ink', KColor.ink, light: true),
              _Swatch('ink-2', KColor.ink2, light: true),
              _Swatch('ink-3', KColor.ink3, light: true),
              _Swatch('hairline', KColor.hairline),
              _Swatch('indicator', KColor.indicator, light: true),
              _Swatch('tint', KColor.indicatorTint),
              _Swatch('gain', KColor.gain, light: true),
              _Swatch('loss', KColor.loss, light: true),
            ]),
            const SizedBox(height: 28),

            // ── Type ──
            _Section('Type — Space Grotesk'),
            Text('Balance display', style: KType.hero()),
            const SizedBox(height: 6),
            Text('Screen title', style: KType.title()),
            const SizedBox(height: 6),
            Text('Section head', style: KType.section()),
            const SizedBox(height: 6),
            Text('Card title', style: KType.cardTitle()),
            const SizedBox(height: 6),
            Text('Body copy — calm, plain, trustworthy. Numbers carry the message.',
                style: KType.body()),
            const SizedBox(height: 8),
            const KEyebrow('Tracked label · eyebrow'),
            const SizedBox(height: 6),
            Text('₦ 1,284,500.00  ·  +2.65%  ·  \$420.18',
                style: KType.cardTitle().tnum),
            const SizedBox(height: 28),

            // ── Buttons ──
            _Section('Buttons'),
            KButton(label: 'Primary action', onPressed: () {}),
            const SizedBox(height: 10),
            KButton(label: 'Secondary', variant: KButtonVariant.secondary, onPressed: () {}),
            const SizedBox(height: 10),
            KButton(label: 'Ghost', variant: KButtonVariant.ghost, onPressed: () {}),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: KButton(label: 'With icon', iconLeft: 'plus', onPressed: () {})),
              const SizedBox(width: 10),
              const Expanded(child: KButton(label: 'Loading', loading: true)),
            ]),
            const SizedBox(height: 10),
            const KButton(label: 'Disabled'),
            const SizedBox(height: 12),
            Row(children: [
              KButton(label: 'Medium', size: KButtonSize.md, fullWidth: false, onPressed: () {}),
              const SizedBox(width: 10),
              KButton(label: 'Small', size: KButtonSize.sm, fullWidth: false, onPressed: () {}),
              const SizedBox(width: 12),
              KIconButton(icon: 'bell', onPressed: () {}),
              const SizedBox(width: 10),
              KIconButton(icon: 'filter', variant: KIconButtonVariant.float, onPressed: () {}),
            ]),
            const SizedBox(height: 28),

            // ── Inputs ──
            _Section('Inputs'),
            const KInput(label: 'Full name', placeholder: 'Ada Okeke', icon: 'profile'),
            const SizedBox(height: 14),
            const KInput(label: 'Amount', prefix: '₦', placeholder: '0.00', numeric: true, helper: 'Buy from ₦1,000'),
            const SizedBox(height: 14),
            const KInput(label: 'BVN', placeholder: '2200…', numeric: true, error: 'Enter all 11 digits'),
            const SizedBox(height: 14),
            const KSearchPill(placeholder: 'Search stocks & ETFs', showFilter: true),
            const SizedBox(height: 14),
            KSegmentedControl(
              value: _seg,
              onChanged: (v) => setState(() => _seg = v),
              options: const [
                KSegmentOption(value: 'buy', label: 'Buy'),
                KSegmentOption(value: 'sell', label: 'Sell'),
              ],
            ),
            const SizedBox(height: 10),
            KSegmentedControl(
              value: _segPay,
              onChanged: (v) => setState(() => _segPay = v),
              options: const [
                KSegmentOption(value: 'email', label: 'Email', icon: 'send'),
                KSegmentOption(value: 'phone', label: 'Phone', icon: 'card'),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < _chipLabels.length; i++)
                KPillChip(
                  label: _chipLabels[i],
                  selected: _chip == i,
                  onTap: () => setState(() => _chip = i),
                ),
            ]),
            const SizedBox(height: 14),
            KFileUpload(
              label: 'Government ID',
              file: _file,
              onPick: () => setState(() => _file = const KFileInfo(name: 'nin-slip.pdf', size: 248320)),
              onRemove: () => setState(() => _file = null),
            ),
            const SizedBox(height: 28),

            // ── Forms ──
            _Section('Toggles'),
            KCheckbox(
              checked: _check,
              onChanged: (v) => setState(() => _check = v),
              label: 'I agree to the client agreement',
              description: 'Required before you can trade',
            ),
            const SizedBox(height: 14),
            KRadio(
              checked: _radio,
              onChanged: (v) => setState(() => _radio = v),
              label: 'Moderate risk',
              description: 'Balanced growth with some volatility',
            ),
            const SizedBox(height: 14),
            KSwitch(
              checked: _switch,
              onChanged: (v) => setState(() => _switch = v),
              label: 'Biometric unlock',
              description: 'Use Face ID to open the app',
            ),
            const SizedBox(height: 28),

            // ── Finance ──
            _Section('Finance'),
            KBalancePanel(
              label: 'Total balance',
              balance: '₦ 1,284,500.00',
              change: '+₦33,200.00 · +2.65% today',
              chart: KLineChart(data: _line, onDark: true),
            ),
            const SizedBox(height: 14),
            Row(children: const [
              Expanded(child: KStatCard(icon: KIcon('wallet', size: 20, color: KColor.ink3), label: 'Invested', value: '₦ 980,000')),
              SizedBox(width: 12),
              Expanded(child: KStatCard(icon: KIcon('arrowUpRight', size: 20, color: KColor.ink3), label: 'Returns', value: '+₦304,500', sub: '+31.1%', subTone: KSubTone.gain)),
            ]),
            const SizedBox(height: 16),
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                KAssetRow(name: 'MTN Nigeria', ticker: 'MTNN', logoColor: const Color(0xFFFFC403), price: '₦ 232.50', change: '+1.31%', sparkline: _spark, onTap: () {}),
                const Divider(height: 1, color: KColor.hairline),
                KAssetRow(name: 'Apple Inc.', ticker: 'AAPL', price: '\$ 214.29', change: '-0.42%', sparkline: _spark, trend: KTrend.loss, onTap: () {}),
                const Divider(height: 1, color: KColor.hairline),
                KAssetRow(name: 'Vanguard S&P 500', ticker: 'VOO', price: '\$ 503.11', change: '+0.58%', sparkline: _spark, onTap: () {}),
              ]),
            ),
            const SizedBox(height: 16),
            KCard(
              child: Row(children: [
                const KAllocationDonut(
                  segments: [
                    KDonutSegment(value: 42),
                    KDonutSegment(value: 28),
                    KDonutSegment(value: 18),
                    KDonutSegment(value: 12),
                  ],
                  centerValue: '4',
                  centerLabel: 'HOLDINGS',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Legend(color: KAllocationDonut.ramp[0], label: 'NGX stocks', pct: '42%'),
                    _Legend(color: KAllocationDonut.ramp[1], label: 'US stocks', pct: '28%'),
                    _Legend(color: KAllocationDonut.ramp[2], label: 'ETFs', pct: '18%'),
                    _Legend(color: KAllocationDonut.ramp[3], label: 'Cash', pct: '12%'),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Feedback ──
            _Section('Feedback'),
            const KToast(tone: KToastTone.success, title: 'Order placed', message: 'Buy 4 MTNN at market.', action: 'View'),
            const SizedBox(height: 10),
            const KToast(tone: KToastTone.error, title: 'Payment failed', message: 'Your card was declined.'),
            const SizedBox(height: 10),
            KToast(tone: KToastTone.info, title: 'Markets close at 2:30 pm', onClose: () {}),
            const SizedBox(height: 20),
            Row(children: const [KSpinner(), SizedBox(width: 16), KSpinner(color: KColor.ink), SizedBox(width: 16), KSpinner(size: 28, stroke: 3)]),
            const SizedBox(height: 20),
            KCard(child: KStatusView(
              tone: KStatusTone.success,
              title: 'Your money is ready to invest',
              message: 'Funds have landed in your naira wallet.',
              primary: 'Start investing',
              onPrimary: () {},
              secondary: 'View receipt',
              onSecondary: () {},
            )),
            const SizedBox(height: 28),

            // ── Navigation & overlays ──
            _Section('Navigation & overlays'),
            Center(child: KBottomNav(active: _nav, onChange: (v) => setState(() => _nav = v))),
            const SizedBox(height: 16),
            KButton(
              label: 'Open bottom sheet',
              variant: KButtonVariant.secondary,
              onPressed: () => showKSheet(
                context,
                title: 'Buy MTN Nigeria',
                footer: KButton(label: 'Review order', onPressed: () => Navigator.pop(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  KInput(label: 'Amount', prefix: '₦', placeholder: '0.00', numeric: true),
                  SizedBox(height: 12),
                  KEyebrow('Markets close at 2:30 pm'),
                ]),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static const _chipLabels = ['All', 'NGX stocks', 'US stocks', 'ETFs', 'Watchlist'];
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        KEyebrow(title, color: KColor.ink),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: KColor.hairline)),
      ]),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, {this.light = false, this.border = false});
  final String name;
  final Color color;
  final bool light;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 64,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(KRadii.button),
        border: border ? Border.all(color: KColor.hairline, width: 1) : null,
      ),
      child: Text(name,
          style: KType.micro(color: light ? KColor.paper : KColor.ink2).copyWith(letterSpacing: 0)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.pct});
  final Color color;
  final String label;
  final String pct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: KType.body(color: KColor.ink, w: KWeight.medium))),
        Text(pct, style: KType.cardTitle().tnum),
      ]),
    );
  }
}
