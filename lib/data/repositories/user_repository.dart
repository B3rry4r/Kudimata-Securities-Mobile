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
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      memberSince: json['memberSince'] as String? ?? '',
    );
  }

  /// Backs the account-personal screen (personal_info_screen.dart), which
  /// needs fields UserProfile doesn't carry — `dob`/`residentialAddress`/
  /// `city`/`state` (see Kudimata-Securities-Backend
  /// src/common/types/user.types.ts's `User` interface). UserProfile itself
  /// is left untouched (models.dart is out of scope for this screen's
  /// wiring), so this is a second, self-contained GET /users/me call
  /// returning a small screen-local view type instead — same convention as
  /// e.g. WalletRepository.BankAccountSummary, HoldingsRepository.PortfolioSummary.
  Future<PersonalInfo> personalInfo() async {
    final response = await _client.get('/users/me');
    final json = response.data as Map<String, dynamic>;
    return PersonalInfo(
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      dob: _formatDob(json['dob'] as String?),
      residentialAddress: json['residentialAddress'] as String? ?? '—',
      city: json['city'] as String? ?? '—',
      state: json['state'] as String? ?? '—',
      cscsNumber: json['cscsNumber'] as String? ?? '—',
      accountStatus: json['accountStatus'] as String? ?? 'active',
    );
  }

  /// PATCH /users/me — self-service partial profile update. Every param is
  /// optional; only the fields passed are sent, matching the backend's
  /// UpdateMeDto (Kudimata-Securities-Backend
  /// src/users/dto/update-me.dto.ts: firstName?/middleName?/lastName?/phone?/residentialAddress?/
  /// dob?/city?/state?, all independently optional, `phone` validated
  /// server-side against `/^\+[1-9]\d{7,14}$/` and `dob` an ISO-8601 date —
  /// callers must normalize both before calling this). Used by
  /// onboarding/personal_details_screen.dart (the post-signup onboarding
  /// step that now collects dob/address/city/state/phone — KYC starts from
  /// BVN and no longer asks for these, 2026-08-07) and
  /// account/personal_info_screen.dart's "Edit details" sheet.
  Future<void> updateProfile({
    String? firstName,
    String? middleName,
    String? lastName,
    String? phone,
    String? residentialAddress,
    String? dob,
    String? city,
    String? state,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (middleName != null) body['middleName'] = middleName;
    if (lastName != null) body['lastName'] = lastName;
    if (phone != null) body['phone'] = phone;
    if (residentialAddress != null) body['residentialAddress'] = residentialAddress;
    if (dob != null) body['dob'] = dob;
    if (city != null) body['city'] = city;
    if (state != null) body['state'] = state;
    await _client.patch('/users/me', data: body);
  }

  /// POST /users/me/freeze — self-service account freeze (2026-08-22 "Soft
  /// Landing" redesign, audit P0). No request body; the backend blocks new
  /// orders/withdrawals and revokes every session immediately. Lifting a
  /// freeze stays a staff action — there is no self-service unfreeze.
  Future<void> freeze() async {
    await _client.post('/users/me/freeze', data: {});
  }

  /// POST /users/me/request-closure — self-service account-closure request
  /// (2026-08-24, mobile canvas screen 90). No request body, same shape as
  /// [freeze] above. Unlike [freeze], this does NOT revoke sessions or
  /// change account status server-side — it only records a closure request
  /// for staff to action; the account stays fully open and functional, so
  /// callers must NOT sign the user out after this succeeds.
  Future<void> requestClosure() async {
    await _client.post('/users/me/request-closure', data: {});
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
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dob,
    required this.residentialAddress,
    required this.city,
    required this.state,
    required this.cscsNumber,
    required this.accountStatus,
  });

  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String phone;
  final String dob; // preformatted "14 Mar 1996", or "—" if none on file
  final String residentialAddress; // or "—" if none on file
  final String city; // or "—" if none on file
  final String state; // or "—" if none on file
  // CHN (the mockup's term for the CSCS clearing house number) — added
  // 2026-08-23 exactness pass (screen-specs.md spec 49 shows a real "CHN"
  // row). `User.cscsNumber` already exists on the backend (per the
  // 2026-08-22 product audit) and GET /users/me already returns it; this
  // repository just wasn't reading the field before.
  final String cscsNumber; // or "—" if not yet assigned
  final String accountStatus; // raw backend value, e.g. "active"/"suspended"

  /// Composed display string — see UserProfile.fullName's same getter for
  /// why this stays a getter rather than a stored field.
  String get fullName => [firstName, middleName, lastName]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(' ');
}
