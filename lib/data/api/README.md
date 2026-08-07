# Kudimata Securities — API layer convention

Read this before wiring any screen to a real endpoint. It is the ONE pattern
every screen-wiring agent must follow — do not invent a per-screen variant.

## Why this exists

This app has neither a network layer nor a state-management package
(confirmed: no http/dio/provider/riverpod/bloc before this pre-step). Every
screen today reads data synchronously via static `MockData.x` calls inside
`build()`. Real API calls are async, so that pattern can't survive as-is —
but we are deliberately NOT adding a state-management package to fix it.
Flutter's own `FutureBuilder` is enough for a one-shot load, and phase 1 has
no caching/offline requirement to justify more machinery.

## Layout

```
lib/data/api/            — this layer (shared, do not duplicate per-screen)
  api_client.dart         ApiClient: configured Dio + auth/refresh/error interceptors
  auth_token_store.dart    AuthTokenStore: flutter_secure_storage wrapper
  api_exception.dart       ApiException: the one exception type you ever catch
  paginated_response.dart  PaginatedResponse<T>: for PaginatedList<T> endpoints
  README.md                this file

lib/data/repositories/   — one file per backend resource (YOU add these)
  asset_repository.dart    EXAMPLE — copy its shape, not its field-mapping
```

## Repositories

One repository class per backend resource (`AssetRepository`,
`PortfolioRepository`, `WalletRepository`, ...), each:

- Takes the shared `ApiClient` in its constructor (not `Dio` directly).
- Exposes `Future<T>` / `Future<List<T>>` methods.
- Is named to mirror the `MockData` accessor it replaces, so the mapping is
  obvious: `MockData.trending` → `AssetRepository.trending()`,
  `MockData.assetByTicker` → `AssetRepository.byTicker(ticker)`,
  `MockData.portfolioHoldings` → `PortfolioRepository.holdings()`, etc.
- Calls `client.get/post/patch/delete` — **never** `client.dio` directly.
  Those verbs guarantee every failure surfaces as `ApiException`, never a
  raw `DioException`.
- Parses `response.data` into the existing domain models in
  `lib/data/models.dart` (do not change those models' shape casually — they
  are what every screen already renders against; if a field is genuinely
  missing, that's a per-screen judgment call to flag, not silently invent).
- For a `PaginatedList<T>` endpoint (check `registry.json` — e.g.
  `GET /transactions`, `GET /orders`, `GET /holdings`), parse with
  `PaginatedResponse<T>.fromJson`. For a bare `list<T>` endpoint (e.g.
  `GET /assets/trending`), parse `response.data` as a plain `List` — do not
  wrap it.

See `lib/data/repositories/asset_repository.dart` for the exact shape.

## The canonical screen pattern

Wrap the screen's existing body-building logic in a `FutureBuilder`. Use
`KLoadingView` for the loading state and `KErrorView` for the error state
(both from `lib/screens/shared/state_views.dart`) — do not invent new
loading/error widgets. On data, render **exactly the same widget tree the
mock version built**, just fed from `snapshot.data` instead of `MockData.x`.

```dart
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _future = _repo.trending();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Asset>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KLoadingView();
        }
        if (snapshot.hasError) {
          return KErrorView(
            onPrimary: () => setState(() => _future = _repo.trending()),
          );
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const KEmptyView.watchlist(); // or whichever KEmptyView(...) fits this screen
        }
        // ...the SAME widget tree the mock build() produced, fed `data`...
        return TrendingList(assets: data);
      },
    );
  }
}
```

Notes:
- `KErrorView` defaults to title "Couldn't load" / a generic message — pass
  `title`/`message` overrides, or use one of its named constructors
  (`.failedLoad`, `.orderFailed`), whichever matches the screen's design.
- `KEmptyView` has convenience constructors (`.holdings`, `.transactions`,
  `.watchlist`) — use the one matching the resource, or the base constructor
  for anything else.
- Keep the `StatelessWidget` → `StatefulWidget` conversion minimal: only the
  `late Future<T> _future` field and the `FutureBuilder` wrapper are new: the
  rest of the widget tree that used to read `MockData.x` inline should be
  extracted into a plain widget/method taking the fetched data as a
  parameter, so it's identical whether fed by mock or live data.

### Pull-to-refresh / repeat-fetch

Where the screen already has (or the design implies) pull-to-refresh, wrap
in `RefreshIndicator` and reassign `_future` the same way a retry does:

```dart
RefreshIndicator(
  onRefresh: () async {
    setState(() => _future = _repo.trending());
    await _future;
  },
  child: FutureBuilder<List<Asset>>(
    future: _future,
    builder: (context, snapshot) => /* ... */,
  ),
)
```

`RefreshIndicator`'s child must be scrollable (a `ListView`/`CustomScrollView`
etc.) even when the content is short — that's a Flutter requirement, not
specific to this pattern. No caching layer, no stale-while-revalidate, no
background refresh — this is phase 1, keep it this simple.

### What NOT to do

- Do not use `StreamBuilder` for a one-shot load.
- Do not add `provider`/`riverpod`/`bloc`/etc — that decision is made; a
  `FutureBuilder` + a `StatefulWidget`'s own `setState` is the whole pattern.
- Do not build a caching/offline layer. Per
  `Kudimata-Securities-Backend/.pipeline/conventions.md`'s runtime contract,
  there is **no offline/connectivity handling** anywhere in this app — an
  `ApiException` just renders the ordinary error state (`KErrorView`),
  nothing fancier. No "you're offline" banner, no retry-with-backoff queue.
- Do not catch `DioException` in a screen or repository — if you ever find
  yourself doing that, you've bypassed `ApiClient`'s `get/post/patch/delete`
  convenience verbs; use those instead so you only ever catch `ApiException`.

## The shared `ApiClient` instance — DONE, this is how you reach it

This is already wired — no wiring agent needs to construct an `ApiClient`.
`lib/main.dart`'s `_KudimataAppState` constructs ONE shared `AuthTokenStore`
and ONE shared `ApiClient` at startup (`initState`, before the first frame),
and assigns the client to `AppState.apiClient` — wiring
`ApiClient.onSessionExpired` to that same `AppState` instance's
`forceSignOut()`, so a failed silent-refresh forces the gated router back to
sign-in automatically.

`ApiClient` did NOT get a second `InheritedWidget` (no `ApiScope`) — it rides
on the `AppScope` this app already threads `AppState` through, as a field:

```dart
class AppState extends ChangeNotifier {
  ...
  late final ApiClient apiClient; // assigned once by main.dart
}
```

**Every screen/repository reaches it exactly one way:**

```dart
AppScope.read(context).apiClient   // non-listening — use this almost always:
                                    // initState, event handlers, constructing
                                    // a repository. apiClient itself never
                                    // changes after startup, so there's no
                                    // reason to opt into AppState-wide rebuilds
                                    // just to read it.

AppScope.of(context).apiClient     // listening — only if this same build()
                                    // already calls AppScope.of(context) for
                                    // other AppState fields; do not call it
                                    // solely to fetch apiClient.
```

Typical repository construction inside a screen's `State`:

```dart
class _MyScreenState extends State<MyScreen> {
  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _future = _repo.trending();
  ...
}
```

(`AppScope.read(context)` is safe to call in `initState`/field initializers
that run after the widget is mounted — it does a non-listening ancestor
lookup, same as any other `AppScope.read(context)` call already used
throughout the app for other AppState reads.)

Do not construct a second `ApiClient` anywhere — there is exactly one, owned
by `AppState`, set once in `main.dart`.
