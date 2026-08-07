// Kudimata Securities — User repository.
//
// See lib/data/api/README.md for the shared convention. Construct with the
// ONE shared ApiClient, reached via `AppScope.read(context).apiClient` —
// never a second ApiClient instance:
//   final _repo = UserRepository(AppScope.read(context).apiClient);
import '../api/api_client.dart';
import '../models.dart';

class UserRepository {
  const UserRepository(this._client);
  final ApiClient _client;

  /// Mirrors MockData.user. GET /users/me — a bare (non-paginated) `User`
  /// object per registry.json.
  Future<UserProfile> me() async {
    final response = await _client.get('/users/me');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  UserProfile _fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      memberSince: json['memberSince'] as String? ?? '',
    );
  }

  /// Backs the account-personal screen (personal_info_screen.dart), which
  /// needs two fields UserProfile doesn't carry — `dob` and
  /// `residentialAddress` (see Kudimata-Securities-Backend
  /// src/common/types/user.types.ts's `User` interface: both were added to
  /// the real User model to replace what were hardcoded literals on that
  /// screen). UserProfile itself is left untouched (models.dart is out of
  /// scope for this screen's wiring), so this is a second, self-contained
  /// GET /users/me call returning a small screen-local view type instead —
  /// same convention as e.g. WalletRepository.BankAccountSummary,
  /// HoldingsRepository.PortfolioSummary.
  Future<PersonalInfo> personalInfo() async {
    final response = await _client.get('/users/me');
    final json = response.data as Map<String, dynamic>;
    return PersonalInfo(
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      dob: _formatDob(json['dob'] as String?),
      residentialAddress: json['residentialAddress'] as String? ?? '—',
    );
  }

  /// PATCH /users/me — self-service partial profile update. Every param is
  /// optional; only the fields passed are sent, matching the backend's
  /// UpdateMeDto (Kudimata-Securities-Backend
  /// src/users/dto/update-me.dto.ts: fullName?/phone?/residentialAddress?/
  /// dob?/city?/state?, all independently optional, `phone` validated
  /// server-side against `/^\+[1-9]\d{7,14}$/` and `dob` an ISO-8601 date —
  /// callers must normalize both before calling this). Used by
  /// onboarding/personal_details_screen.dart (the post-signup onboarding
  /// step that now collects dob/address/city/state/phone — KYC starts from
  /// BVN and no longer asks for these, 2026-08-07) and
  /// account/personal_info_screen.dart's "Edit details" sheet.
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? residentialAddress,
    String? dob,
    String? city,
    String? state,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (residentialAddress != null) body['residentialAddress'] = residentialAddress;
    if (dob != null) body['dob'] = dob;
    if (city != null) body['city'] = city;
    if (state != null) body['state'] = state;
    await _client.patch('/users/me', data: body);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `dob` is an ISO-8601 *date* (e.g. "1996-03-14", no time component) per
  /// user.types.ts — formatted "14 Mar 1996" to match the design literal it
  /// replaces. Same `_months`-table shape every other repository's
  /// `_formatDate` uses for timestamps (TransactionRepository,
  /// WalletRepository, OrdersRepository), just without the time suffix.
  static String _formatDob(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }
}

/// Screen-local view of the User resource for account-personal — see
/// [UserRepository.personalInfo].
class PersonalInfo {
  const PersonalInfo({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dob,
    required this.residentialAddress,
  });

  final String fullName;
  final String email;
  final String phone;
  final String dob; // preformatted "14 Mar 1996", or "—" if none on file
  final String residentialAddress; // or "—" if none on file
}
