// Rights issue detail (screen 82, 2026-08-23 "Soft Landing"). Wired per
// lib/data/api/README.md's FutureBuilder convention:
// CorporateActionsRepository.rightsIssues() (GET /rights-issues) replaces
// the static `RightsIssueFixture` this screen used to be pushed with, and
// .electRightsIssue() (POST /rights-issues/:id/elect) replaces the
// always-"not available yet" Take up / Let it lapse buttons.
//
// NOTE — no `extra`/id argument: app_router.dart's GoRoute for
// Routes.corpActionsRightsIssue constructs `RightsIssueScreen()` with no
// forwarded `extra` (router files are out of scope for this pass — see
// corporate_actions_screen.dart's header comment for the full reasoning),
// so this screen can't be told WHICH rights issue to show via navigation.
// It fetches the caller's own list instead and picks the most relevant
// item itself: the first still-open one the caller hasn't elected on yet,
// falling back to the most recent item overall (so a caller with only
// closed/already-decided issues still sees their own history rather than
// an empty screen). A real per-item detail route (GET /rights-issues/:id
// doesn't even exist server-side yet) is a genuine follow-up, not
// something this pass can wire.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/corporate_actions_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_widgets.dart';

typedef _ScreenData = ({List<RightsIssueListItem> items, String walletBalance});

class RightsIssueScreen extends StatefulWidget {
  const RightsIssueScreen({super.key});

  @override
  State<RightsIssueScreen> createState() => _RightsIssueScreenState();
}

class _RightsIssueScreenState extends State<RightsIssueScreen> {
  late final _repo = CorporateActionsRepository(AppScope.read(context).apiClient);
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late Future<_ScreenData> _future = _load();

  // Canvas #s82's KInput carries a real "Wallet ₦214,300.00 · part of the
  // entitlement is fine" helper — fetched alongside the rights-issue list
  // rather than a second screen-level FutureBuilder, same combined-load
  // convention every other screen in this app uses.
  Future<_ScreenData> _load() async {
    final (items, walletBalance) = await (_repo.rightsIssues(), _walletRepo.balance()).wait;
    return (items: items, walletBalance: walletBalance);
  }

  RightsIssueListItem? _pickRelevant(List<RightsIssueListItem> items) {
    for (final item in items) {
      if (item.status == CorpActionStatus.open && !item.alreadyElected) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ScreenData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KCorpActionScaffold(
            title: 'Rights issue',
            child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: KLoadingView()),
          );
        }
        if (snapshot.hasError) {
          return KCorpActionScaffold(
            title: 'Rights issue',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: KErrorView(onPrimary: () => setState(() => _future = _load())),
            ),
          );
        }
        final data = snapshot.data!;
        final item = _pickRelevant(data.items);
        if (item == null) {
          return const KCorpActionScaffold(
            title: 'Rights issue',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: KEmptyView(
                icon: 'portfolio',
                title: 'No rights issue to show',
                message: 'Rights issues on companies you hold will show up here.',
              ),
            ),
          );
        }
        return KCorpActionScaffold(
          title: '${item.ticker} rights issue',
          child: _RightsIssueDetail(
            key: ValueKey(item.id),
            repo: _repo,
            item: item,
            walletBalance: data.walletBalance,
          ),
        );
      },
    );
  }
}

class _RightsIssueDetail extends StatefulWidget {
  const _RightsIssueDetail({
    super.key,
    required this.repo,
    required this.item,
    required this.walletBalance,
  });
  final CorporateActionsRepository repo;
  final RightsIssueListItem item;
  final String walletBalance;

  @override
  State<_RightsIssueDetail> createState() => _RightsIssueDetailState();
}

class _RightsIssueDetailState extends State<_RightsIssueDetail> {
  late RightsIssueListItem _item = widget.item;
  late final _controller = TextEditingController(text: _item.entitlementUnits.toString());
  late int _units = _item.entitlementUnits;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final parsed = int.tryParse(value.trim());
    setState(() {
      _units = parsed == null ? 0 : parsed.clamp(0, _item.entitlementUnits);
    });
  }

  String get _costLabel => _formatNaira(_units * _item.subscriptionPriceKobo);

  Future<void> _takeUp() async {
    if (_units <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final election = await widget.repo.electRightsIssue(
        _item.id,
        decision: RightsIssueDecision.takeUp,
        unitsSubscribed: _units,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _item = _item.withElection(election);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _lapse() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final election =
          await widget.repo.electRightsIssue(_item.id, decision: RightsIssueDecision.lapse);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _item = _item.withElection(election);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _item;
    final election = r.election;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: KColor.paper,
            border: Border.all(color: KColor.hairline, width: 1),
            borderRadius: BorderRadius.circular(KRadii.card),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              KFactRow(
                label: 'Your entitlement',
                value: '${r.entitlementUnits} shares · ${r.ratioText}',
                first: true,
              ),
              KFactRow(label: 'Rights price', value: _formatNaira(r.subscriptionPriceKobo)),
              KFactRow(
                label: 'Cost to take it all',
                value: _formatNaira(r.entitlementUnits * r.subscriptionPriceKobo),
                emphasis: true,
              ),
              KFactRow(label: 'Closes', value: _fullDate(r.closeDate)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (election != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const KStatusPill(status: KStatus.approved, label: 'Decided', small: true),
                    const SizedBox(width: 10),
                    Text(_fullDate(election.decidedAt), style: KType.micro(color: KColor.ink3)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  election.decision == RightsIssueDecision.takeUp
                      ? 'You took up ${election.unitsSubscribed} of ${election.entitlementUnits} shares '
                          '(${_formatNaira(election.unitsSubscribed * r.subscriptionPriceKobo)}).'
                      : 'You let this offer lapse.',
                  style: KType.data(color: KColor.ink2),
                ),
              ],
            ),
          ),
        ] else ...[
          KInput(
            label: 'How many will you take?',
            controller: _controller,
            numeric: true,
            keyboardType: TextInputType.number,
            suffix: 'of ${r.entitlementUnits}',
            helper: 'Wallet ${widget.walletBalance} · part of the entitlement is fine',
            onChanged: _onChanged,
          ),
          const SizedBox(height: 12),
          KExplainPanel(
            title: 'What happens if I ignore it?',
            body: 'Your slice of ${r.ticker} gets smaller and you keep your '
                '${_formatNaira(r.entitlementUnits * r.subscriptionPriceKobo)}. Neither choice is '
                'wrong — taking it up only makes sense if you still want more ${r.ticker}.',
          ),
          const SizedBox(height: 20),
          KButton(
            label: _units > 0 ? 'Take up $_units for $_costLabel' : 'Take up 0 shares',
            loading: _busy,
            onPressed: _units > 0 && !_busy ? _takeUp : null,
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Let it lapse',
            variant: KButtonVariant.ghost,
            onPressed: _busy ? null : _lapse,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: KType.micro(color: KColor.loss)),
          ],
        ],
      ],
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-03-27T14:30:00.000Z" -> "27 Mar 2026 · 14:30".
String _fullDate(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} ${local.year} · $hh:$mm';
}

/// Minor-unit kobo -> "₦3,360.00" (thousands-grouped, 2dp).
String _formatNaira(int kobo) {
  final abs = kobo.abs();
  final whole = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final wholeStr = whole.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '₦$wholeStr.$minor';
}
