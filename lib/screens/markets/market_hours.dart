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
library;

bool isNgxOpenNow() {
  final wat = DateTime.now().toUtc().add(const Duration(hours: 1));
  if (wat.weekday == DateTime.saturday || wat.weekday == DateTime.sunday) {
    return false;
  }
  final minutesSinceMidnight = wat.hour * 60 + wat.minute;
  return minutesSinceMidnight >= (10 * 60) && minutesSinceMidnight < (14 * 60 + 30);
}
