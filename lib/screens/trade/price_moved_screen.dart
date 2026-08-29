// Flow G, spec screen 62 — "Price moved at the open". UI-ready, NOT wired
// into a route (2026-08-22 exactness pass). This screen exists to show what
// happens when a limit order queued via _MarketClosedBuySheet (trade_flows.dart,
// spec screen 61) opens above its limit — but reaching it for real needs an
// event this mobile client has no way to receive yet: a push/notification
// the instant the market opens and the fill outcome is known, or a
// dedicated "queued orders" surface in the Orders screen that can detect
// this specific state. Neither exists today. Building this unwired (rather
// than skipping it) means the visual design is ready the moment that real
// trigger is built — see docs/redesign/PLAN.md.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/screens/markets/market_hours.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class PriceMovedScreen extends StatelessWidget {
  const PriceMovedScreen({
    super.key,
    required this.ticker,
    required this.queuedAt,
    required this.lastClose,
    required this.openedAt,
    required this.openedPct,
    required this.limitPrice,
    required this.heldAmount,
    required this.onBuyAtOpen,
    required this.onRaiseLimit,
    required this.onCancel,
  });

  final String ticker;
  final String queuedAt;
  final String lastClose;
  final String openedAt;
  final String openedPct;
  final String limitPrice;
  final String heldAmount;
  final VoidCallback onBuyAtOpen;
  final VoidCallback onRaiseLimit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Queued order'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "Needs your decision" callout — warm-tinted, NOT grape/sun.
              // Spec's own colour note: this is the one distinct "action
              // needed" treatment, deliberately different from routine info
              // cards or milestones.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: KColor.warmTint, borderRadius: KRadii.featureR),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEEDS YOUR DECISION'.upper,
                        style: KType.label(color: KColor.warmPress)),
                    const SizedBox(height: 10),
                    Text('$ticker opened at $openedAt — above your $limitPrice limit',
                        style: KType.section()),
                    const SizedBox(height: 8),
                    Text(
                      'Nothing was bought and nothing was charged. Your $heldAmount is '
                      'still held for this order until $ngxCloseLabel today.',
                      style: KType.body(color: KColor.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Row(label: 'You queued', value: queuedAt),
              _Row(label: "Last close", value: lastClose),
              _Row(label: 'Opened at', value: '$openedAt · $openedPct', valueColor: KColor.loss),
              _Row(label: 'Your limit', value: limitPrice),
              const SizedBox(height: 20),
              KNudgeCard(
                tone: KNudgeTone.grape,
                title: 'Why did it move?',
                body: 'The opening price carries overnight news — that is exactly what a limit protects you from.',
              ),
              const SizedBox(height: 24),
              KButton(label: 'Buy at $openedAt instead', onPressed: onBuyAtOpen),
              const SizedBox(height: 10),
              KButton(
                label: 'Raise my limit',
                variant: KButtonVariant.secondary,
                onPressed: onRaiseLimit,
              ),
              const SizedBox(height: 10),
              KButton(
                label: 'Cancel and return the money',
                variant: KButtonVariant.ghost,
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: KColor.hairline, width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KType.body(color: KColor.ink2)),
          Text(value, style: KType.body(color: valueColor ?? KColor.ink, w: KWeight.medium).tnum),
        ],
      ),
    );
  }
}
