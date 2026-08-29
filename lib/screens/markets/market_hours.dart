// NGX market-hours heuristic (2026-08-22 "Soft Landing" exactness pass,
// Flow G screens 60-61). Client-side only — a simple clock check, NOT
// authoritative exchange-status data from the backend (no such field exists
// anywhere in this app's API surface). Good enough to drive the UI's
// open/closed framing; NOT good enough to be trusted for anything that
// actually needs to know precisely when the exchange opens/closes (real
// settlement timing, etc. — those stay server-side concerns).
//
// NGX trades 10:00-14:30 WAT, Monday-Friday. 2026-08-24 fix: this used to
// read the DEVICE's local clock and just assume it was already set to Lagos
// time — wrong for any tester/investor whose device isn't literally on WAT,
// which silently showed the wrong open/closed state (missing sparklines,
// wrong banner) for most real users. WAT is a fixed UTC+1 offset (Nigeria
// observes no daylight saving), so it's computed from UTC directly instead —
// correct regardless of the device's own timezone setting.
import 'package:flutter/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// NGX's real session, in WAT minutes from midnight. The ONE definition —
/// `isNgxOpenNow()` below and every user-visible label both read these, so a
/// label can no longer disagree with the open/closed state it sits beside.
///
/// It could, and did — in both directions, which is the interesting part.
///
/// markets_screen.dart carried its own `const _ngxCloseTime = '4:30pm'`, copied
/// from artboard s24, while `isNgxOpenNow()` here closed the session at 14:30.
/// The label and the state disagreed, so the pill could read "Open till 4:30pm"
/// while the app believed the market had shut two hours earlier.
///
/// **16:30 is correct** — ruled by the product owner 2026-08-29 ("NGX CLOSES
/// 16:30 NOT 14"), and the canvas agreed with them all along. The bug was the
/// code, not the design. Worth recording because the first fix went the wrong
/// way: seeing a hardcoded label beside a computed time, the label looked like
/// the copied-from-a-mockup error and the computation looked authoritative. It
/// was the other way round. A number in code is not evidence merely because it
/// is in code.
const int kNgxOpenMinutes = 10 * 60;        // 10:00 WAT
const int kNgxCloseMinutes = 16 * 60 + 30;  // 16:30 WAT (R-46)

/// [kNgxCloseMinutes] as the app writes times to investors, e.g. "2:30pm".
String get ngxCloseLabel => _clockLabel(kNgxCloseMinutes);

/// [kNgxOpenMinutes] in the same form, e.g. "10:00".
String get ngxOpenLabel => _clockLabel(kNgxOpenMinutes, twentyFour: true);

String _clockLabel(int minutes, {bool twentyFour = false}) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (twentyFour) return '$h:${m.toString().padLeft(2, '0')}';
  final suffix = h >= 12 ? 'pm' : 'am';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')}$suffix';
}

bool isNgxOpenNow() {
  final wat = DateTime.now().toUtc().add(const Duration(hours: 1));
  if (wat.weekday == DateTime.saturday || wat.weekday == DateTime.sunday) {
    return false;
  }
  final minutesSinceMidnight = wat.hour * 60 + wat.minute;
  return minutesSinceMidnight >= kNgxOpenMinutes && minutesSinceMidnight < kNgxCloseMinutes;
}

const _weekdayNames = <int, String>{
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The most recent weekday strictly before [from] (skips weekends) — used
/// below to name whose closing prices are on screen.
DateTime _previousTradingDay(DateTime from) {
  var d = from.subtract(const Duration(days: 1));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.subtract(const Duration(days: 1));
  }
  return d;
}

/// The next weekday strictly after [from] (skips weekends) — used below to
/// say when the market reopens.
DateTime _nextTradingDay(DateTime from) {
  var d = from.add(const Duration(days: 1));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// "today" / "tomorrow" / a weekday name — when the market next opens,
/// relative to right now. Shared by [marketClosedBannerSubtitle] and
/// markets_screen.dart's "You can still place an order" nudge, which used
/// to hardcode "queues for 10:00 tomorrow" regardless of the actual day —
/// same class of bug as the banner subtitle below, found the same pass.
String marketNextOpenLabel() {
  final wat = DateTime.now().toUtc().add(const Duration(hours: 1));
  final today = _dateOnly(wat);
  final isWeekday = wat.weekday != DateTime.saturday && wat.weekday != DateTime.sunday;
  final minutesSinceMidnight = wat.hour * 60 + wat.minute;
  if (isWeekday && minutesSinceMidnight < 10 * 60) return 'today';
  final nextOpen = _nextTradingDay(today);
  final daysUntilOpen = nextOpen.difference(today).inDays;
  return daysUntilOpen <= 1 ? 'tomorrow' : _weekdayNames[nextOpen.weekday]!;
}

/// Copy for the "market is closed" banner (markets_screen.dart and
/// wherever else shows it), e.g. "Opens today at 10:00 · prices below are
/// Friday's close" — computed from the real WAT clock so it's correct on
/// any day, not just Mon-after-Fri. 2026-08-24 fix: this used to be a
/// single hardcoded string that always said "Opens tomorrow at 10:00 ·
/// prices below are Friday's close" regardless of the actual day — reported
/// live as "looks like a hard code" (it was).
String marketClosedBannerSubtitle() {
  final wat = DateTime.now().toUtc().add(const Duration(hours: 1));
  final today = _dateOnly(wat);
  final isWeekday = wat.weekday != DateTime.saturday && wat.weekday != DateTime.sunday;
  final minutesSinceMidnight = wat.hour * 60 + wat.minute;
  final beforeOpenToday = isWeekday && minutesSinceMidnight < 10 * 60;
  final lastCloseDay = beforeOpenToday
      ? _previousTradingDay(today)
      : (isWeekday ? today : _previousTradingDay(today));

  return "Opens ${marketNextOpenLabel()} at 10:00 · prices below are ${_weekdayNames[lastCloseDay.weekday]}'s close";
}

/// The "market is closed" banner — extracted 2026-08-24 from
/// markets_screen.dart (its original, only home) so it can also appear on
/// watchlist_screen.dart and asset_detail_screen.dart, neither of which
/// showed any closed-market indication at all before this (reported live
/// as "markets dont show closed too").
class KMarketClosedBanner extends StatelessWidget {
  const KMarketClosedBanner({super.key, this.onSetAlert});

  /// s39's ("Market closed") own secondary footer button, "Set a price
  /// alert" — the artboard's second cited entry point into `s49`
  /// (SetPriceAlertScreen), alongside the asset page's bell icon
  /// (asset_detail_screen.dart's own `Routes.setPriceAlert` wire). Only a
  /// caller that knows a single ticker can offer this — markets_screen.dart
  /// shows this banner at list level, with no one asset to alert on, and
  /// passes null; the affordance is then simply omitted rather than shown
  /// as a dead control.
  final VoidCallback? onSetAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: KColor.track, borderRadius: KRadii.cardR),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KIcon('clock', size: 18, color: KColor.ink2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('The market is closed', style: KType.cardTitle()),
                    const SizedBox(height: 2),
                    Text(marketClosedBannerSubtitle(), style: KType.data(color: KColor.ink2)),
                  ],
                ),
              ),
            ],
          ),
          if (onSetAlert != null) ...[
            const SizedBox(height: 12),
            KButton(
              label: 'Set a price alert',
              variant: KButtonVariant.secondary,
              size: KButtonSize.sm,
              onPressed: onSetAlert,
            ),
          ],
        ],
      ),
    );
  }
}
