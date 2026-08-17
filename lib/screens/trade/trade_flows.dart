// Kudimata Securities — Stage 6: Trade buy/sell flows as bottom sheets.
// Mirrors trade-screens.jsx: AmountSheet (+ over-limit error state), ReviewSheet,
// SuccessSheet — shared between Buy and Sell via a `side` flag. Each flow is a
// sequence of showKSheet presentations; the launching screen (asset detail) stays
// behind the scrim, so we don't re-render the design's TradeBackdrop here.
//
// WIRED: order placement calls OrderPlacementRepository.placeOrder ->
// `POST /orders` (see lib/data/repositories/order_placement_repository.dart).
// On ApiException the Review sheet swaps to KErrorView.orderFailed instead of
// silently "succeeding".
//
// FIXED BUG (was: Review sheet never received what the investor actually
// typed in the Amount sheet — it always showed a hardcoded "₦50,000"/
// "186.3 shares" regardless of input, so a real order would have submitted
// the wrong amount). The Amount sheet now computes an [_OrderInput] (naira
// value + share units, whichever the investor actually entered, per the
// naira/shares toggle) and threads it through Review -> confirm -> the
// `POST /orders` payload -> the Success message.
//
// FIXED BUG (was: the Amount sheet's "Holding" line was a hardcoded
// "120 shares · ₦32,208" literal, unrelated to the investor's real position
// size). The Amount sheet now fetches HoldingsRepository.byTicker (sell,
// `GET /holdings/:ticker`) once in initState and shows the resolved figure —
// "…" while loading, "—" if the fetch fails, since this is a secondary
// informational element and must not block or crash the trade flow.
//
// NON-CUSTODIAL WALLET REDESIGN (backend supersedes.json S-11): Kudimata
// holds no client funds, so a buy has no stored balance to show or "Max"
// against (dropped from the Amount sheet's buy-side chips/line below) — a
// buy now opens a Flutterwave checkout after Review and only reaches the
// broker once payment is confirmed, via the new Awaiting-payment step
// between Review and Success (order_placement_repository.dart's
// [OrderResult] — POST /orders now returns `status: 'awaiting_payment'` +
// `checkoutUrl` for a buy instead of filling synchronously). Sell is
// unaffected — it still fills immediately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/order_placement_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:go_router/go_router.dart';

// Mock daily order limit (₦). Amounts above this trip the over-limit state.
const double _kDailyLimit = 500000;

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Buy flow: amount → (over-limit?) → review → success. Gated on
/// [tradingEligibilityGap] — browsing an asset's detail page never requires
/// KYC/suitability, only actually trading does (also enforced server-side,
/// OrdersService.assertEligibleToTrade, since this check alone is
/// bypassable).
Future<void> showBuyFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runTradeFlow(context, asset, side: _Side.buy);
}

/// Sell flow: amount → review → success. Same gate as [showBuyFlow].
Future<void> showSellFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runTradeFlow(context, asset, side: _Side.sell);
}

/// Runs the three sheets in sequence, each one only opening once the
/// previous has FULLY dismissed (awaiting showKSheet's own returned Future,
/// which resolves exactly when that sheet's route is gone) — rather than
/// each sheet manually `Navigator.pop()`ing itself and immediately opening
/// the next sheet on the same still-transitioning root navigator. That
/// pop-then-immediately-push-again pattern is a known source of a stale
/// modal barrier (from the sheet still mid-exit-animation) sitting above
/// the newly-presented sheet and absorbing its taps — reported live as
/// "even the success purchase modal, the buttons don't respond" (2026-08-15).
/// Each sheet now returns its result through the SAME showKSheet Future
/// instead of reaching for Navigator/context itself to chain onward.
Future<void> _runTradeFlow(BuildContext context, Asset asset, {required _Side side}) async {
  final amountInput = await _showAmountSheet(context, asset, side: side);
  if (amountInput == null || !context.mounted) return;

  final placed = await _showReviewSheet(context, asset, side: side, input: amountInput);
  if (placed == null || !context.mounted) return;

  // Buy only: payment was just collected via a Flutterwave checkout, but the
  // order hasn't reached the broker yet — wait for it to resolve before
  // declaring success. Sell never returns 'awaitingPayment' (it fills
  // synchronously), so this step is skipped entirely for a sell.
  if (placed.order.status == OrderStatus.awaitingPayment) {
    final resolved = await _showAwaitingPaymentSheet(context, order: placed.order);
    if (resolved == null || !context.mounted) return;
    if (resolved.status == OrderStatus.rejected || resolved.status == OrderStatus.expired) {
      await _showPaymentOutcomeFailureSheet(context, expired: resolved.status == OrderStatus.expired);
      return;
    }
  }

  await _showSuccessSheet(context, asset, side: side, input: placed.input);
}

/// Shows a sheet pointing the investor at whichever KYC/suitability step
/// they're missing instead of opening the trade sheet. Returns true (no
/// sheet shown) once they're actually eligible.
Future<bool> _ensureEligibleToTrade(BuildContext context) async {
  final gap = tradingEligibilityGap(AppScope.read(context));
  if (gap == null) return true;
  await showKSheet<void>(
    context,
    child: KStatusView(
      tone: KStatusTone.pending,
      title: gap.title,
      message: gap.message,
      primary: 'Continue',
      onPrimary: () {
        Navigator.of(context).pop();
        context.push(gap.route);
      },
      secondary: 'Not now',
      onSecondary: () => Navigator.of(context).pop(),
    ),
  );
  return false;
}

enum _Side { buy, sell }

extension on _Side {
  bool get isSell => this == _Side.sell;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared amount/price helpers.
// ─────────────────────────────────────────────────────────────────────────────

/// Asset.price arrives as a preformatted display string ("₦268.40" /
/// "$228.10") — strip the currency symbol/commas to get a usable double.
double _parsePrice(String price) =>
    double.tryParse(price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

/// Whole-naira value -> "₦50,000" (no decimals, matching this flow's mock
/// figures — Fee/Amount/Total were always shown as whole naira).
String _formatNaira(double value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final abs = negative ? -rounded : rounded;
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buf.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return '${negative ? '−' : ''}₦$buf';
}

/// What the investor actually entered in the Amount sheet, resolved to both
/// units — this is what threads through Review -> confirm -> the order
/// payload -> the Success message, replacing the old hardcoded figures.
class _OrderInput {
  const _OrderInput({
    required this.unit,
    required this.amountNaira,
    required this.units,
  });

  /// 'naira' or 'shares' — mirrors the Amount sheet's KSegmentedControl
  /// toggle; decides which of amountNaira/units is the investor's real
  /// input and which is the derived estimate.
  final String unit;
  final double amountNaira;
  final double units;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Amount entry (shared). Naira/shares unit toggle + quick-amount chips.
// ─────────────────────────────────────────────────────────────────────────────

Future<_OrderInput?> _showAmountSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
}) {
  return showKSheet<_OrderInput>(
    context,
    title: side.isSell ? 'Sell ${asset.ticker}' : 'Buy ${asset.ticker}',
    child: _AmountSheet(asset: asset, side: side),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.asset, required this.side});
  final Asset asset;
  final _Side side;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _amount = TextEditingController(text: '50,000');
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  String _unit = 'naira';
  late String _quick = widget.side.isSell ? '50%' : '₦50k';

  // Holding line (sell only) — fetched once when the sheet opens (GET
  // /holdings/:ticker), replacing the old hardcoded '120 shares · ₦32,208'
  // literal. null while the fetch is in flight; '—' if it fails — this is a
  // secondary informational element, not the core trade flow, so a failure
  // here must not block or crash the sheet. No buy-side equivalent: Kudimata
  // holds no client funds, so there's no wallet balance to show or "Max"
  // against (see this file's header — S-11).
  String? _holdingLabel;

  // Raw numeric mirror of the above — needed so the percentage chips below
  // can compute an actual value rather than just a label. null until the
  // fetch resolves; those chips no-op until then.
  double? _holdingUnits;

  @override
  void initState() {
    super.initState();
    if (widget.side.isSell) _loadHolding();
  }

  Future<void> _loadHolding() async {
    try {
      final h = await _holdingsRepo.byTicker(widget.asset.ticker);
      if (!mounted) return;
      setState(() {
        _holdingLabel = '${h.units} shares · ${h.marketValue}';
        _holdingUnits = double.tryParse(h.units.replaceAll(RegExp('[^0-9.]'), ''));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _holdingLabel = '—');
    }
  }

  // Resolves a tapped quick-amount chip to a naira/unit value and writes it
  // into the amount field in whichever unit [_unit] is currently showing.
  // Fixed-naira buy chips (₦10k/₦25k/₦50k) always work; sell's percentage
  // chips depend on the holding fetch above and no-op until it resolves.
  void _applyQuick(String chip) {
    double? naira;
    double? units;

    if (widget.side.isSell) {
      final holding = _holdingUnits;
      if (holding == null) return;
      final pct = switch (chip) {
        '25%' => 0.25,
        '50%' => 0.50,
        '75%' => 0.75,
        'All' => 1.0,
        _ => null,
      };
      if (pct == null) return;
      units = holding * pct;
    } else {
      naira = switch (chip) {
        '₦10k' => 10000.0,
        '₦25k' => 25000.0,
        '₦50k' => 50000.0,
        _ => null,
      };
      if (naira == null) return;
    }

    setState(() {
      _quick = chip;
      if (_unit == 'naira') {
        final value = naira ?? (units! * _price);
        _amount.text = _formatNaira(value).replaceFirst('₦', '');
      } else {
        final value = units ?? (_price > 0 ? naira! / _price : 0);
        _amount.text = value.toStringAsFixed(1);
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  // Parse the (comma-grouped) figure the investor typed — its meaning
  // (naira amount vs share units) depends on [_unit].
  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  double get _price => _parsePrice(widget.asset.price);

  /// Share units, whichever way the investor entered the order.
  double get _units =>
      _unit == 'shares' ? _amountValue : (_price > 0 ? _amountValue / _price : 0);

  /// Naira value, whichever way the investor entered the order.
  double get _amountNaira => _unit == 'naira' ? _amountValue : _amountValue * _price;

  bool get _overLimit => !widget.side.isSell && _amountNaira > _kDailyLimit;

  @override
  Widget build(BuildContext context) {
    final isSell = widget.side.isSell;
    final chips = isSell ? const ['25%', '50%', '75%', 'All'] : const ['₦10k', '₦25k', '₦50k'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          label: _unit == 'naira' ? 'Amount' : 'Shares',
          controller: _amount,
          numeric: true,
          amount: true,
          prefix: _unit == 'naira' ? '₦' : null,
          suffix: _unit == 'shares' ? 'shares' : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          error: _overLimit
              ? 'This order exceeds your daily limit of ₦500,000.'
              : null,
        ),
        const SizedBox(height: 14),
        KSegmentedControl(
          value: _unit,
          onChanged: (v) => setState(() => _unit = v),
          options: const [
            KSegmentOption(value: 'naira', label: '₦'),
            KSegmentOption(value: 'shares', label: 'Shares'),
          ],
        ),
        if (!_overLimit) ...[
          const SizedBox(height: 10),
          Text(
            _unit == 'naira'
                ? '≈ ${_units.toStringAsFixed(1)} shares'
                : '≈ ${_formatNaira(_amountNaira)}',
            style: KType.micro(color: KColor.ink3).tnum.copyWith(letterSpacing: 0.04 * 10),
          ),
        ],

        // Holding line + ghost shortcut — sell only. No buy-side equivalent
        // (no wallet balance; see this file's header — S-11).
        if (isSell) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: KType.body(color: KColor.ink2),
                    children: [
                      const TextSpan(text: 'Holding '),
                      TextSpan(
                        text: _holdingLabel ?? '…',
                        style: KType.body(color: KColor.ink, w: KWeight.medium).tnum,
                      ),
                    ],
                  ),
                ),
              ),
              KButton(
                label: 'Sell all',
                variant: KButtonVariant.ghost,
                size: KButtonSize.sm,
                fullWidth: false,
                onPressed: () {}, // shortcut affordance — mirrors design (no-op here)
              ),
            ],
          ),
        ],

        // Quick-amount chips.
        const SizedBox(height: 16),
        Row(
          children: [
            for (final c in chips) ...[
              if (c != chips.first) const SizedBox(width: 8),
              Expanded(
                child: KPillChip(
                  label: c,
                  selected: _quick == c,
                  onTap: () => _applyQuick(c),
                ),
              ),
            ],
          ],
        ),

        // Primary action — turns into "Adjust amount" while over limit.
        const SizedBox(height: 22),
        _overLimit
            ? KButton(
                label: 'Adjust amount',
                variant: KButtonVariant.secondary,
                onPressed: () {
                  // Stay on the amount sheet so the user can lower the figure.
                  setState(() => _amount.text = '50,000');
                },
              )
            : KButton(
                label: 'Review order',
                onPressed: () {
                  // Pop WITH the result rather than popping-then-immediately-
                  // showing the review sheet ourselves — see _runTradeFlow's
                  // doc comment for why that pattern is unsafe here.
                  Navigator.of(context).pop(_OrderInput(
                    unit: _unit,
                    amountNaira: _amountNaira,
                    units: _units,
                  ));
                },
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Review order (shared). Summary rows + risk ack + confirm.
// ─────────────────────────────────────────────────────────────────────────────

/// What Review hands back once POST /orders succeeds — the investor's
/// original input (for Success's message) plus the placed [OrderResult]
/// (for the buy-only Awaiting-payment step, which needs its id/checkoutUrl).
class _PlacedOrder {
  const _PlacedOrder({required this.input, required this.order});
  final _OrderInput input;
  final OrderResult order;
}

Future<_PlacedOrder?> _showReviewSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
  required _OrderInput input,
}) {
  return showKSheet<_PlacedOrder>(
    context,
    title: 'Review order',
    child: _ReviewSheet(asset: asset, side: side, input: input),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.asset, required this.side, required this.input});
  final Asset asset;
  final _Side side;
  final _OrderInput input;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

// Flat mock fee — registry.json's Order resource has no fee field, so
// unlike amount/units (the investor's real input) this stays a fixed design
// figure, same as before.
const double _kFeeNaira = 125;

class _ReviewSheetState extends State<_ReviewSheet> {
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
  bool _agreed = false;
  bool _placing = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return KErrorView.orderFailed(
        onPrimary: () {
          setState(() => _failed = false);
          _confirm();
        },
        onSecondary: () => Navigator.of(context).pop(),
      );
    }

    final isSell = widget.side.isSell;
    final input = widget.input;
    final ticker = widget.asset.ticker;
    final price = widget.asset.price;

    // Rows now reflect the investor's actual input: whichever of
    // amount/shares they typed is shown as the primary figure, the other is
    // the derived estimate — replacing the old hardcoded '₦50,000'/'186.3'.
    final rows = <(String, String)>[
      ('Asset', ticker),
      ('Type', 'Market'),
      if (input.unit == 'naira') ...[
        ('Amount', _formatNaira(input.amountNaira)),
        ('Est. shares', input.units.toStringAsFixed(1)),
      ] else ...[
        ('Shares', input.units.toStringAsFixed(1)),
        ('Est. amount', _formatNaira(input.amountNaira)),
      ],
      ('Est. price', price),
      ('Fee', _formatNaira(_kFeeNaira)),
    ];

    final total = isSell ? input.amountNaira - _kFeeNaira : input.amountNaira + _kFeeNaira;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (k, v) in rows) _SummaryRow(label: k, value: v),

        // Total / proceeds emphasis line.
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 15, 0, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isSell ? 'Proceeds' : 'Total',
                  style: KType.cardTitle(w: KWeight.semibold)),
              Text(_formatNaira(total),
                  style: KType.section().tnum.copyWith(fontWeight: KWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text(
          'Prices move; your order fills at the best available price.',
          style: KType.body(color: KColor.ink3),
        ),

        const SizedBox(height: 18),
        KCheckbox(
          checked: _agreed,
          label: 'I understand the risks',
          onChanged: (v) => setState(() => _agreed = v),
        ),

        const SizedBox(height: 22),
        KButton(
          label: isSell ? 'Confirm sale' : 'Confirm purchase',
          loading: _placing,
          onPressed: (_agreed && !_placing) ? _confirm : null,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _placing = true);
    final side = widget.side.isSell ? OrderSide.sell : OrderSide.buy;
    final input = widget.input;
    try {
      final OrderResult order;
      if (input.unit == 'shares') {
        order = await _repo.placeOrder(
          ticker: widget.asset.ticker,
          side: side,
          units: input.units,
        );
      } else {
        order = await _repo.placeOrder(
          ticker: widget.asset.ticker,
          side: side,
          amountKobo: (input.amountNaira * 100).round(),
        );
      }
      if (!mounted) return;
      // Pop WITH the result — see _runTradeFlow's doc comment for why this
      // sheet doesn't show the next step itself.
      Navigator.of(context).pop(_PlacedOrder(input: input, order: order));
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _failed = true;
      });
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KType.body(color: KColor.ink2)),
          Text(value, style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2.5 — Awaiting payment (buy only). Opens the Flutterwave checkout
// [OrderResult.checkoutUrl] and polls GET /orders/:id until the webhook-
// driven backend moves the order off 'awaiting_payment' (S-11). No deep
// link/redirect callback is configured in this app, so polling — not a
// return-URL handoff — is how this app finds out payment landed.
// ─────────────────────────────────────────────────────────────────────────────

const _kPollInterval = Duration(seconds: 3);

Future<OrderResult?> _showAwaitingPaymentSheet(
  BuildContext context, {
  required OrderResult order,
}) {
  return showKSheet<OrderResult>(
    context,
    title: 'Complete payment',
    child: _AwaitingPaymentSheet(order: order),
  );
}

class _AwaitingPaymentSheet extends StatefulWidget {
  const _AwaitingPaymentSheet({required this.order});
  final OrderResult order;

  @override
  State<_AwaitingPaymentSheet> createState() => _AwaitingPaymentSheetState();
}

class _AwaitingPaymentSheetState extends State<_AwaitingPaymentSheet> {
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
  Timer? _poll;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _openCheckout();
    _poll = Timer.periodic(_kPollInterval, (_) => _checkStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _openCheckout() async {
    final url = widget.order.checkoutUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    setState(() => _opening = true);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort — the "Open checkout" button below lets the investor
      // retry the hand-off manually; polling keeps running regardless.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _checkStatus() async {
    try {
      final result = await _repo.getOrder(widget.order.id);
      if (!mounted) return;
      if (result.status != OrderStatus.awaitingPayment) {
        _poll?.cancel();
        Navigator.of(context).pop(result);
      }
    } catch (_) {
      // Transient network hiccup — the next tick tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Complete your payment in the browser, then come back here — '
          'this updates automatically once we receive it.',
          textAlign: TextAlign.center,
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 22),
        KButton(
          label: 'Open checkout',
          loading: _opening,
          onPressed: _opening ? null : _openCheckout,
        ),
        const SizedBox(height: 10),
        KButton(
          label: "I'll do this later",
          variant: KButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ],
    );
  }
}

/// Shown when the awaiting-payment step resolves to something other than a
/// fill: the checkout window expired unpaid (nothing was captured), or
/// payment succeeded but the broker couldn't fill the order (already being
/// auto-refunded server-side — see backend OrdersService.resolveBuyPaymentOutcome).
Future<void> _showPaymentOutcomeFailureSheet(BuildContext context, {required bool expired}) {
  return showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: expired ? 'Checkout expired' : 'Order not filled',
        message: expired
            ? "Your checkout window closed before payment was completed. Nothing was charged — try again whenever you're ready."
            : 'Your payment was received, but the order could not be filled. It\'s being refunded to your bank account.',
        primary: 'Done',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Success (shared). KStatusView outcome; "View portfolio" / "Done"
// per the design. The orders screen has its own entry points (Home / Wallet).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showSuccessSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
  required _OrderInput input,
}) {
  HapticFeedback.lightImpact();
  final amountStr = _formatNaira(input.amountNaira);
  return showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.success,
        title: 'Order placed',
        message: side.isSell
            ? 'You sold $amountStr of ${asset.ticker}. Proceeds settle T+3.'
            : 'You bought $amountStr of ${asset.ticker}. Shares settle T+3.',
        primary: 'View portfolio',
        onPrimary: () {
          Navigator.of(context).pop();
          context.go(Routes.portfolio);
        },
        secondary: 'Done',
        onSecondary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}
