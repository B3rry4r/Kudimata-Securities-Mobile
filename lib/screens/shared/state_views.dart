// Kudimata Securities — shared empty / loading / error / success state views.
// Ported from states.jsx (StatesBoard). On-system: white surfaces, hairline,
// one clear action. Leans on KStatusView + KSpinner; the neutral empty medallion
// and skeleton shimmer are local (no neutral StatusView tone exists).
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import '../../widgets/widgets.dart';

// ── Centred result wrapper (Centered in the JSX) ────────────────────────────
class KCentered extends StatelessWidget {
  const KCentered({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: child,
      ),
    );
  }
}

// ── EMPTY ───────────────────────────────────────────────────────────────────
/// Illustrated scene + title + message + one action — the design system's
/// StatusView pattern (readme.md names the plain icon-in-a-circle medallion
/// this replaces explicitly as the thing "the redesign moved away from").
/// [illustrationName] renders a real scene on its tinted plate; omit it and
/// the old medallion (icon in a circle) still renders, so any call site that
/// hasn't been given a matching scene yet keeps working unchanged.
class KEmptyView extends StatelessWidget {
  const KEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationName,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  /// Convenience builders mirroring the design's EmptyHoldings / EmptyTransactions
  /// / EmptyWatchlist frames.
  const KEmptyView.holdings({super.key, this.onAction})
      : icon = 'portfolio',
        title = 'No holdings yet',
        message = 'Your investments will show here. Buy from ₦1,000.',
        actionLabel = 'Browse markets',
        illustrationName = 'empty-portfolio',
        secondaryActionLabel = null,
        onSecondaryAction = null;

  const KEmptyView.transactions({super.key, this.onAction})
      : icon = 'transfer',
        title = 'No transactions yet',
        message = 'Money you add, invest or withdraw will appear here.',
        actionLabel = 'Add money',
        illustrationName = 'empty-wallet',
        secondaryActionLabel = null,
        onSecondaryAction = null;

  const KEmptyView.watchlist({super.key, this.onAction})
      : icon = 'eye', // design used a bookmark glyph (not in the fixed KIcon set)
        title = 'Nothing saved yet',
        message = 'Save a stock to follow its price here.',
        actionLabel = 'Browse markets',
        illustrationName = 'empty-watchlist',
        secondaryActionLabel = null,
        onSecondaryAction = null;

  final String icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? illustrationName;

  /// Second, ghost-variant action below the primary one — e.g. screen 58's
  /// Portfolio empty state ("Browse the NGX" primary + "Add money first"
  /// ghost). Nullable/additive so every existing single-action call site is
  /// unaffected; only rendered when [actionLabel] is also present, matching
  /// the canvas's own primary-then-secondary button order.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final safeIcon = KIcon.has(icon) ? icon : 'eye';
    return KCentered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustrationName != null)
            KIllustration(illustrationName!, role: KIlloRole.state)
          else
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColor.paper,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: KIcon(safeIcon, size: 30, color: KColor.ink),
            ),
          const SizedBox(height: 22),
          Text(title, textAlign: TextAlign.center, style: KType.title()),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Text(message,
                textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: KButton(label: actionLabel!, onPressed: onAction),
            ),
            if (secondaryActionLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: KButton(
                  label: secondaryActionLabel!,
                  variant: KButtonVariant.ghost,
                  onPressed: onSecondaryAction,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── ERROR ─────────────────────────────────────────────────────────────────--
/// StatusView (tone error) wrapped centred. Mirrors ErrFailedLoad / ErrOrderFailed
/// / ErrSuspended.
class KErrorView extends StatelessWidget {
  const KErrorView({
    super.key,
    this.title = "Couldn't load",
    this.message = 'Something went wrong on our end. Your money is safe.',
    this.primary = 'Retry',
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.secondaryVariant = KButtonVariant.secondary,
  });

  /// Generic portfolio/data load failure (design: ErrFailedLoad).
  const KErrorView.failedLoad({super.key, this.onPrimary})
      : title = "Couldn't load your portfolio",
        message = 'Something went wrong on our end. Your money is safe.',
        primary = 'Retry',
        secondary = null,
        onSecondary = null,
        secondaryVariant = KButtonVariant.secondary;

  /// Order failure (design: ErrOrderFailed). [message] lets a caller surface
  /// the REAL backend reason (e.g. "Your wallet balance is not sufficient
  /// to cover this order.") instead of always showing the generic fallback
  /// below — added 2026-08-20 after a report that a genuinely-correct
  /// insufficient-balance rejection just looked like an unexplained generic
  /// failure, since trade_flows.dart's catch used to discard
  /// ApiException.message entirely.
  const KErrorView.orderFailed({super.key, this.onPrimary, this.onSecondary, String? message})
      : title = 'Order failed',
        message = message ?? "Your order didn't go through. No money has left your wallet.",
        primary = 'Try again',
        secondary = 'Back',
        secondaryVariant = KButtonVariant.secondary;

  final String title;
  final String message;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  /// See [KStatusView.secondaryVariant] — defaults to the boxed `secondary`
  /// look every existing call site already expects; pass `ghost` to match
  /// a canvas screen (e.g. 59 "Offline & error") whose second button is
  /// ghost-variant.
  final KButtonVariant secondaryVariant;

  @override
  Widget build(BuildContext context) {
    return KCentered(
      child: KStatusView(
        tone: KStatusTone.error,
        title: title,
        message: message,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryVariant: secondaryVariant,
      ),
    );
  }
}

// ── SUCCESS ──────────────────────────────────────────────────────────────--
/// StatusView (tone success) wrapped centred. Mirrors SuccessPayment.
class KSuccessView extends StatelessWidget {
  const KSuccessView({
    super.key,
    required this.title,
    this.message,
    this.primary = 'Done',
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String title;
  final String? message;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return KCentered(
      child: KStatusView(
        tone: KStatusTone.success,
        title: title,
        message: message,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
      ),
    );
  }
}

// ── KEY/VALUE ROW ────────────────────────────────────────────────────────--
/// A plain "label … value" metadata row (tabular-nums value, right-aligned)
/// — the small data-summary cards on state screens (89 "Dormant account",
/// 90 "Close your account", 92 "Locked out") use this, distinct from
/// `KAccountRow`'s tappable icon+title+chevron pattern. `first` drops the
/// top hairline, same convention as `KAccountRow.first`.
class KKeyValueRow extends StatelessWidget {
  const KKeyValueRow({super.key, required this.label, required this.value, this.first = false});
  final String label;
  final String value;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
          const SizedBox(width: 12),
          Text(value, style: KType.data(color: KColor.ink).tnum),
        ],
      ),
    );
  }
}

// ── LOADING ─────────────────────────────────────────────────────────────--
/// A simple centred spinner for inline/section loading.
class KLoadingView extends StatelessWidget {
  const KLoadingView({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Center(child: KSpinner(size: size));
}

/// Shimmering skeleton block (the `.sk` class in the design). [dark] tints it for
/// placement inside the ink feature panel.
class KSkeleton extends StatefulWidget {
  const KSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.dark = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool dark;

  @override
  State<KSkeleton> createState() => _KSkeletonState();
}

class _KSkeletonState extends State<KSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.dark ? const Color(0x1FFFFFFF) : KColor.track;
    final hi = widget.dark ? const Color(0x33FFFFFF) : KColor.hairline;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, hi, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// List skeleton (design: SkeletonList) — a hairline card of avatar+two-line rows
/// with a trailing spinner. Good default placeholder for any pushed list screen.
class KSkeletonList extends StatelessWidget {
  const KSkeletonList({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 16, KSpace.gutter, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KSkeleton(width: 150, height: 24),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: KRadii.cardR,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int i = 0; i < rows; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: KColor.hairline, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const KSkeleton(width: 40, height: 40, radius: 999),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              KSkeleton(width: 140, height: 13),
                              SizedBox(height: 8),
                              KSkeleton(width: 90, height: 11),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            KSkeleton(width: 64, height: 13),
                            SizedBox(height: 8),
                            KSkeleton(width: 44, height: 11),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: KSpinner(size: 22)),
          ),
        ],
      ),
    );
  }
}
