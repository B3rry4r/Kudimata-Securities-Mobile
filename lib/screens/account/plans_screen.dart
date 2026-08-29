// Plans & credits (screen 53, 2026-08-22 "Soft Landing"). 2026-08-24: real
// credits/cancel flow — direct product instruction ("please also set up
// points subscriptions... its a dud"). Buying MORE credits is currently
// disabled server-side (AiCreditsService.subscribe throws
// PURCHASES_NOT_AVAILABLE) — wallet-debit billing for a digital
// subscription was a real App Store/Play Store compliance violation,
// caught and reverted 2026-08-24; the real fix is native platform IAP,
// not yet integrated. The plan cards and their prices stay visible (real
// catalog data) so the UI isn't lying about what plans exist, but tapping
// "Choose" surfaces that plain "not available yet" message rather than a
// generic error. Free signup credits, the ledger and every real AI call
// site (explain/digest/glossary) are unaffected.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/ai_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late final _aiRepo = AiRepository(AppScope.read(context).apiClient);
  late Future<(AiCreditStatus, List<AiPlan>)> _future = _load();

  bool _busy = false;

  Future<(AiCreditStatus, List<AiPlan>)> _load() async {
    final statusFuture = _aiRepo.credits();
    final plansFuture = _aiRepo.plans();
    return (await statusFuture, await plansFuture);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _subscribe(String plan, String planName) async {
    setState(() => _busy = true);
    try {
      await _aiRepo.subscribe(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You're on $planName now.")),
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_BALANCE') {
        _showInsufficientBalanceSheet(planName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await _aiRepo.cancelPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your plan won't renew. You keep your remaining credits.")),
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showInsufficientBalanceSheet(String planName) {
    showKSheet<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: KStatusView(
          tone: KStatusTone.error,
          title: "Wallet balance too low",
          message: "$planName needs more than what's in your wallet right now. Add money and try again.",
          primary: 'Add money',
          onPrimary: () {
            Navigator.of(context).pop();
// `go`, never `push` — Routes.wallet is a tab branch root, and
            // pushing one detaches it from the shell so the bottom nav
            // stops responding. See price_alerts_screen.dart's note.
            context.go(Routes.wallet);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Plans & credits',
      child: FutureBuilder<(AiCreditStatus, List<AiPlan>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(onPrimary: _reload);
          }
          final (status, plans) = snapshot.data!;
          return _PlansBody(
            status: status,
            plans: plans,
            busy: _busy,
            onSubscribe: _subscribe,
            onCancel: _cancel,
          );
        },
      ),
    );
  }
}

class _PlansBody extends StatelessWidget {
  const _PlansBody({
    required this.status,
    required this.plans,
    required this.busy,
    required this.onSubscribe,
    required this.onCancel,
  });

  final AiCreditStatus status;
  final List<AiPlan> plans;
  final bool busy;
  final void Function(String plan, String planName) onSubscribe;
  final VoidCallback onCancel;

  String _formatNaira(int kobo) {
    final naira = kobo / 100;
    final whole = naira.floor();
    final s = whole.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '₦$s';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status.plan == null
              ? "You're on the free trial — ${status.creditsRemaining} credit${status.creditsRemaining == 1 ? '' : 's'} left."
              : '${status.creditsRemaining} credit${status.creditsRemaining == 1 ? '' : 's'} left'
                  '${status.planRenewsAt != null ? ' · renews ${_formatDate(status.planRenewsAt!)}' : ''}.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < plans.length; i++) ...[
          if (i != 0) const SizedBox(height: 12),
          Builder(builder: (context) {
            final plan = plans[i];
            final isCurrent = status.plan == plan.key;
            return KPlanCard(
              name: plan.name,
              price: _formatNaira(plan.priceKobo),
              credits: '${plan.credits}',
              featured: plan.key == 'pro',
              note: isCurrent ? 'Your current plan' : null,
              features: plan.features,
              action: isCurrent
                  ? KButton(
                      label: 'Cancel plan',
                      variant: KButtonVariant.secondary,
                      loading: busy,
                      onPressed: busy ? null : onCancel,
                    )
                  : KButton(
                      label: 'Choose ${plan.name}',
                      variant: plan.key == 'pro' ? KButtonVariant.warm : KButtonVariant.primary,
                      loading: busy,
                      onPressed: busy ? null : () => onSubscribe(plan.key, plan.name),
                    ),
            );
          }),
        ],
        const SizedBox(height: 12),
        Text(
          "Prices, fees and risk labels stay free. Reading a glossary term's definition is free too — "
              '"Explain further", asset explanations and portfolio digests use a credit.',
          style: KType.data(color: KColor.ink3),
        ),
      ],
    );
  }
}
