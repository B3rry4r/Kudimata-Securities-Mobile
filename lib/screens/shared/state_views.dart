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
/// Neutral empty medallion + title + message + one action. The design's bookmark
/// glyph is not in the fixed KIcon set, so watchlist falls back to 'eye'.
class KEmptyView extends StatelessWidget {
  const KEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Convenience builders mirroring the design's EmptyHoldings / EmptyTransactions
  /// / EmptyWatchlist frames.
  const KEmptyView.holdings({super.key, this.onAction})
      : icon = 'portfolio',
        title = 'No holdings yet',
        message = 'Your investments will show here. Buy from ₦1,000.',
        actionLabel = 'Browse markets';

  const KEmptyView.transactions({super.key, this.onAction})
      : icon = 'transfer',
        title = 'No transactions yet',
        message = 'Money you add, invest or withdraw will appear here.',
        actionLabel = 'Add money';

  const KEmptyView.watchlist({super.key, this.onAction})
      : icon = 'eye', // design used a bookmark glyph (not in the fixed KIcon set)
        title = 'Nothing saved yet',
        message = 'Save a stock or ETF to follow its price here.',
        actionLabel = 'Browse markets';

  final String icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final safeIcon = KIcon.has(icon) ? icon : 'eye';
    return KCentered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
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
  });

  /// Generic portfolio/data load failure (design: ErrFailedLoad).
  const KErrorView.failedLoad({super.key, this.onPrimary})
      : title = "Couldn't load your portfolio",
        message = 'Something went wrong on our end. Your money is safe.',
        primary = 'Retry',
        secondary = null,
        onSecondary = null;

  /// Order failure (design: ErrOrderFailed).
  const KErrorView.orderFailed({super.key, this.onPrimary, this.onSecondary})
      : title = 'Order failed',
        message =
            "Your order didn't go through. No money has left your wallet.",
        primary = 'Try again',
        secondary = 'Back';

  final String title;
  final String message;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

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
                            : const BorderSide(color: KColor.hairline, width: 1),
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
