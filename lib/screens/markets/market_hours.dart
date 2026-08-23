// NGX market-hours heuristic (2026-08-22 "Soft Landing" exactness pass,
// Flow G screens 60-61). Client-side only — a simple local-clock check, NOT
// authoritative exchange-status data from the backend (no such field exists
// anywhere in this app's API surface). Good enough to drive the UI's
// open/closed framing; NOT good enough to be trusted for anything that
// actually needs to know precisely when the exchange opens/closes (real
// settlement timing, etc. — those stay server-side concerns).
//
// NGX trades 10:00-14:30, Monday-Friday, device-local time. No timezone
// handling: this assumes the device is set to Lagos time, same assumption
// every other "today"/"this week" string already elsewhere in this app makes.
library;

bool isNgxOpenNow() {
  final now = DateTime.now();
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
    return false;
  }
  final minutesSinceMidnight = now.hour * 60 + now.minute;
  return minutesSinceMidnight >= (10 * 60) && minutesSinceMidnight < (14 * 60 + 30);
}
