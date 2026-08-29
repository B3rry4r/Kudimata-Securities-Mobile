// Kudimata Securities — Market status repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient`.
//
// Backs GET /market-status (2026-08-24) — the real WAT-clock open/closed
// computation moved server-side so a staff member can force open/closed
// from the admin dashboard (Settings -> Market status) to test document/
// statement/receipt flows without waiting for the real 10:00-16:30 WAT
// trading window. See lib/screens/markets/market_hours.dart for how
// AppState consumes this.
import '../api/api_client.dart';

class MarketStatus {
  const MarketStatus({required this.open, required this.mode});
  final bool open;
  final String mode;
}

class MarketStatusRepository {
  const MarketStatusRepository(this._client);
  final ApiClient _client;

  Future<MarketStatus> fetch() async {
    final response = await _client.get('/market-status');
    final data = response.data as Map<String, dynamic>;
    return MarketStatus(open: data['open'] as bool, mode: data['mode'] as String);
  }
}
