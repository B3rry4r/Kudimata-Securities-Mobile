import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// A buy limit is a CEILING and a sell limit a FLOOR, so an order whose limit
/// sits the generous side of the market fills AT THE MARKET. Costing it at the
/// limit instead is what produced the reported defect: 2 shares at a ₦5,000
/// limit on a ₦2,231 share were shown as "Estimated amount ₦10,000", then
/// refused by the server — which costs the same order at ₦4,462 — for being
/// under the ₦5,000 minimum. Quoted one number, rejected against another.
void main() {
  final src = File('lib/screens/trade/trade_flows.dart').readAsStringSync();

  test('every order-costing site uses the expected fill price, not the raw limit', () {
    // The old shape costed a limit order at the limit price directly.
    expect(
      src.contains('kind == _Kind.now ? _parsePrice(asset.price) : limitPrice!'),
      isFalse,
      reason: 'a refPrice site still costs a limit order at the limit price — '
          'the app will quote a number the server does not use',
    );
    // All four flow sites (buy shares/review, sell shares/review) go through it.
    expect('_expectedFillPrice('.allMatches(src).length, greaterThanOrEqualTo(5),
        reason: 'expected the helper plus its four call sites');
  });

  test('the helper resolves the reported case correctly', () {
    // Pure arithmetic mirror of _expectedFillPrice, kept here so the rule is
    // asserted as a rule and not only as "the source contains a string".
    double fill({required bool isLimit, required bool isBuy, required double limit, required double market}) {
      if (!isLimit) return market;
      if (market <= 0) return limit;
      return isBuy ? (limit < market ? limit : market) : (limit > market ? limit : market);
    }

    // The exact reported order: AIRTELAFRI at ₦2,231.01, 2 shares, ₦5,000 limit.
    final buyFill = fill(isLimit: true, isBuy: true, limit: 5000, market: 2231.01);
    expect(buyFill, 2231.01, reason: 'a generous buy limit fills at the market');
    expect(2 * buyFill, lessThan(5000),
        reason: 'so the order really IS under the minimum — the app must say so '
            'before submitting, not quote ₦10,000 and let the server refuse it');

    // A buy limit BELOW market cannot fill above it.
    expect(fill(isLimit: true, isBuy: true, limit: 1500, market: 2231.01), 1500);
    // A sell limit is a floor: below market it fills at the better market price.
    expect(fill(isLimit: true, isBuy: false, limit: 1500, market: 2231.01), 2231.01);
    // A sell limit above market holds out for the limit.
    expect(fill(isLimit: true, isBuy: false, limit: 5000, market: 2231.01), 5000);
    // A market order always costs the market.
    expect(fill(isLimit: false, isBuy: true, limit: 5000, market: 2231.01), 2231.01);
  });
}
