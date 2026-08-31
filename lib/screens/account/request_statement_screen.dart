// Request a statement — artboard s56, `docs/design/redesign-2026-08/
// 06 Account and Support.dc.html` (plus dark twin s56d). Pushed from s52's
// own footer button (statements_screen.dart), which used to keep this
// button's label/icon but repoint the tap at the one action that existed
// (generate the current month, in place) because nothing backed a custom
// date range. That gap is now closed —
// `POST /statements/request` (Kudimata-Securities-Backend's
// StatementGeneratorService.generateRange) renders and stores a real PDF
// over an arbitrary `[from, to]` window and emails it — so the button
// pushes here as s52 itself draws.
//
// What s56 actually asks for, read off the raw markup rather than assumed:
//   1. A period — three presets ("This month"/"This year"/"Choose dates")
//      plus an explicit From/To date pair. All three are real: presets
//      resolve to concrete dates client-side (same "client resolves a
//      filter before it hits the wire" convention statements_screen.dart's
//      year chips already use), "Choose dates" hands control to the two
//      date fields directly.
//   2. A broker — "All brokers, one document" (recommended) vs "Blue
//      Marina only". Only the first is real: this backend has no broker
//      dimension anywhere (Statement/Order/Holding all carry no broker
//      field — the same standing gap statement_detail_screen.dart and
//      statements_screen.dart's own header already document), and
//      StatementGeneratorService.generateRange hardcodes the single
//      sponsoring broker into the one section every statement renders. "All
//      brokers, one document" is therefore not a choice here so much as a
//      statement of fact — it is what every generated statement already
//      is — so it renders as a fixed, real confirmation card rather than a
//      dead second option with nothing behind it.
//   3. Delivery — emailed to the investor's own address, which the backend
//      now really does (EmailMessageService, the `document-ready`
//      template). The canvas's own copy ("usually within an hour") assumes
//      an async render queue that does not exist: generation is
//      synchronous, in this same request, the same way the existing
//      "prepare this month" action on s52 already works — so the subtitle
//      states the real timing instead of transcribing a delay this backend
//      never has.
//
// "Earliest available" is the investor's own real `memberSince`
// (UserRepository.me(), already on `UserProfile` — no new backend field
// needed), not a guess — and the same value the backend independently
// enforces server-side, so a request this screen allows can never be
// rejected for predating the account.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/models.dart' show UserProfile;
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

enum _Preset { thisMonth, thisYear, custom }

class RequestStatementScreen extends StatefulWidget {
  const RequestStatementScreen({super.key});

  @override
  State<RequestStatementScreen> createState() => _RequestStatementScreenState();
}

class _RequestStatementScreenState extends State<RequestStatementScreen> {
  late final _statementsRepo = StatementsRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<UserProfile> _future = _userRepo.me();

  bool _boundsApplied = false;
  _Preset _preset = _Preset.thisMonth;
  DateTime? _from;
  DateTime? _to;
  bool _submitting = false;
  String? _error;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _applyPreset(_Preset preset, DateTime earliest, DateTime today) {
    _preset = preset;
    switch (preset) {
      case _Preset.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        _from = start.isBefore(earliest) ? earliest : start;
        _to = today;
      case _Preset.thisYear:
        final start = DateTime(today.year, 1, 1);
        _from = start.isBefore(earliest) ? earliest : start;
        _to = today;
      case _Preset.custom:
        _from ??= earliest;
        _to ??= today;
    }
  }

  Future<void> _pickFrom(DateTime earliest, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? earliest,
      firstDate: earliest,
      lastDate: _to ?? today,
      helpText: 'From',
    );
    if (picked == null) return;
    setState(() {
      _preset = _Preset.custom;
      _from = _dateOnly(picked);
    });
  }

  Future<void> _pickTo(DateTime earliest, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? today,
      firstDate: _from ?? earliest,
      lastDate: today,
      helpText: 'To',
    );
    if (picked == null) return;
    setState(() {
      _preset = _Preset.custom;
      _to = _dateOnly(picked);
    });
  }

  Future<void> _submit() async {
    final from = _from;
    final to = _to;
    if (_submitting || from == null || to == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _statementsRepo.request(from: from, to: to);
      if (!mounted) return;
      // s56's own "Email me this statement" navigates back to s52 — the
      // `true` tells statements_screen.dart to reload its list so the just-
      // requested statement shows up without a manual pull-to-refresh.
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KAccountSubScaffold(title: 'Request a statement', child: KLoadingView());
        }
        if (snapshot.hasError) {
          return KAccountSubScaffold(
            title: 'Request a statement',
            child: KErrorView(onPrimary: () => setState(() => _future = _userRepo.me())),
          );
        }

        final profile = snapshot.data!;
        final today = _dateOnly(DateTime.now());
        final joined = DateTime.tryParse(profile.memberSince);
        final earliest = joined == null ? today : _dateOnly(joined);
        if (!_boundsApplied) {
          _boundsApplied = true;
          _applyPreset(_Preset.thisMonth, earliest, today);
        }
        final from = _from ?? earliest;
        final to = _to ?? today;

        return KAccountSubScaffold(
          title: 'Request a statement',
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: KType.micro(color: KColor.loss)),
                const SizedBox(height: 9),
              ],
              Text(
                'Sent to ${profile.email}. Statements older than six years '
                'are archived, ask support for those.',
                style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0, height: 1.5),
              ),
              const SizedBox(height: 9),
              KButton(
                label: _submitting ? 'Sending…' : 'Email me this statement',
                loading: _submitting,
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Which period?', style: KType.title()),
              const SizedBox(height: 6),
              Text(
                'We build it now and email you a copy.',
                style: KType.body(color: KColor.ink2),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PeriodPill(
                      label: 'This month',
                      selected: _preset == _Preset.thisMonth,
                      onTap: () => setState(() => _applyPreset(_Preset.thisMonth, earliest, today)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PeriodPill(
                      label: 'This year',
                      selected: _preset == _Preset.thisYear,
                      onTap: () => setState(() => _applyPreset(_Preset.thisYear, earliest, today)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PeriodPill(
                      label: 'Choose dates',
                      selected: _preset == _Preset.custom,
                      onTap: () => setState(() => _preset = _Preset.custom),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'From',
                      text: _shortDate(from),
                      highlighted: _preset == _Preset.custom,
                      onTap: () => _pickFrom(earliest, today),
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: 'To',
                      text: _shortDate(to),
                      highlighted: _preset == _Preset.custom,
                      onTap: () => _pickTo(earliest, today),
                      required: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Earliest available: ${_longDate(earliest)}, the day you joined.',
                style: KType.data(color: KColor.ink3),
              ),
              const SizedBox(height: 22),
              Text('Which broker?', style: KType.cardTitle()),
              const SizedBox(height: 10),
              const _BrokerCard(),
            ],
          ),
        );
      },
    );
  }
}

/// Period preset pill — s56's own three-way row ("This
/// month"/"This year"/"Choose dates"). Genuinely different visual shape
/// from the shared [KPillChip] (tinted fill + coloured text on selection,
/// not a solid purple fill + white text), same "screen-local rather than a
/// fork" call this screen's own file family already makes for
/// [_DocumentRow] in statements_screen.dart.
class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? KColor.indicatorTint : KColor.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? KColor.indicator : KColor.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: KType.data(
            color: selected ? KColor.indicator : KColor.ink,
            w: selected ? KWeight.bold : KWeight.semibold,
          ).copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

/// One From/To date field — tap opens the platform date picker (same
/// `showDatePicker` this app already uses for date-of-birth entry in
/// bvn_nin.dart/personal_details_screen.dart, not a bespoke calendar).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.text,
    required this.highlighted,
    required this.onTap,
    this.required = false,
  });
  final String label;
  final String text;
  final bool highlighted;
  final VoidCallback onTap;

  /// See KInput.required — renders a red asterisk beside the label.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        KType.data(color: KColor.ink3, w: KWeight.semibold).copyWith(fontSize: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        required
            ? Semantics(
                label: '$label, required',
                excludeSemantics: true,
                child: RichText(
                  text: TextSpan(
                    text: label,
                    style: labelStyle,
                    children: [
                      TextSpan(text: ' *', style: labelStyle.copyWith(color: KColor.loss)),
                    ],
                  ),
                ),
              )
            : Text(label, style: labelStyle),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 56,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: KColor.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted ? KColor.indicator : KColor.hairline,
                width: highlighted ? 1.5 : 1,
              ),
            ),
            child: Text(text, style: KType.cardTitle()),
          ),
        ),
      ],
    );
  }
}

/// "Which broker?" — s56 draws this as a two-option picker ("All brokers,
/// one document" vs "Blue Marina only"), but this backend has no broker
/// dimension for a second option to mean anything (see this file's own
/// header). What renders is the one real, already-true state — every
/// statement this backend generates already covers the single sponsoring
/// broker — as a fixed confirmation card, not a control: there is nothing
/// for a second selectable state to switch to, so it carries no `onTap`
/// rather than one that would do nothing.
class _BrokerCard extends StatelessWidget {
  const _BrokerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColor.indicator, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('All brokers, one document', style: KType.cardTitle()),
                Text('Recommended', style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: KColor.indicator, shape: BoxShape.circle),
            child: KIcon('check', size: 11, color: KColor.featureInk),
          ),
        ],
      ),
    );
  }
}

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "1 Jan 2026" — matches s56's own date-field format exactly.
String _shortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

/// "14 March 2026" — matches s56's own "Earliest available" caption format.
String _longDate(DateTime d) => '${d.day} ${_monthsLong[d.month - 1]} ${d.year}';
