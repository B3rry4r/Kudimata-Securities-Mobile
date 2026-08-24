// personal_details_screen.dart's (onboarding, post-signup) two picker
// sheets — Nigerian state of residence and the phone country-code — plus the
// country-code dataset backing the phone field. Originally built for the old
// kyc/personal_details.dart screen; moved here when that screen was deleted
// (personal details moved out of KYC into onboarding, 2026-08-07). lib/widgets/
// is FROZEN (docs/BUILD_CONTRACT.md), so these are file-local, non-widget-
// library additions living alongside personal_details_screen.dart rather
// than in the shared widget library.
//
// Both sheets reuse showKSheet/KCard/KSearchPill/KIcon exactly the way
// bank_accounts_screen.dart's `_AddBankAccountSheet` composes a scrollable,
// searchable picker sheet — no native DropdownButton/DropdownButtonFormField
// anywhere here, to stay visually consistent with the rest of the app.
//
// Country data: hand-curated locally, no package added — 186 countries
// spanning every populated region (not just a token handful), each with its
// name, ISO-3166-1 alpha-2 code, and ITU-T E.164 calling code. Flag emoji
// are derived from the ISO2 code (regional-indicator Unicode trick) rather
// than hand-typed, so they can't drift from the code. This mirrors the
// app's existing pattern of hardcoding small, static, well-known datasets
// locally (e.g. the legal document titles) instead of standing up a backend
// endpoint for something that essentially never changes.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// One entry in the phone country-code list.
@immutable
class KPhoneCountry {
  const KPhoneCountry({
    required this.name,
    required this.iso2,
    required this.dial,
    required this.flag,
  });

  final String name;
  final String iso2;

  /// ITU-T E.164 calling code, WITHOUT the leading '+' (e.g. '234').
  final String dial;
  final String flag;

  /// e.g. '+234'.
  String get dialLabel => '+$dial';
}

/// Broad (186-country) phone country-code dataset. Nigeria leads (this
/// app's default selection); the rest are grouped roughly by region rather
/// than sorted alphabetically, so nearby/likely markets surface first when
/// an investor scrolls before typing a search query.
const List<KPhoneCountry> kPhoneCountries = [
  KPhoneCountry(name: 'Nigeria', iso2: 'NG', dial: '234', flag: '🇳🇬'),
  KPhoneCountry(name: 'Ghana', iso2: 'GH', dial: '233', flag: '🇬🇭'),
  KPhoneCountry(name: 'Kenya', iso2: 'KE', dial: '254', flag: '🇰🇪'),
  KPhoneCountry(name: 'South Africa', iso2: 'ZA', dial: '27', flag: '🇿🇦'),
  KPhoneCountry(name: 'Egypt', iso2: 'EG', dial: '20', flag: '🇪🇬'),
  KPhoneCountry(name: 'Ethiopia', iso2: 'ET', dial: '251', flag: '🇪🇹'),
  KPhoneCountry(name: 'Tanzania', iso2: 'TZ', dial: '255', flag: '🇹🇿'),
  KPhoneCountry(name: 'Uganda', iso2: 'UG', dial: '256', flag: '🇺🇬'),
  KPhoneCountry(name: 'Algeria', iso2: 'DZ', dial: '213', flag: '🇩🇿'),
  KPhoneCountry(name: 'Morocco', iso2: 'MA', dial: '212', flag: '🇲🇦'),
  KPhoneCountry(name: 'Tunisia', iso2: 'TN', dial: '216', flag: '🇹🇳'),
  KPhoneCountry(name: 'Libya', iso2: 'LY', dial: '218', flag: '🇱🇾'),
  KPhoneCountry(name: 'Sudan', iso2: 'SD', dial: '249', flag: '🇸🇩'),
  KPhoneCountry(name: 'South Sudan', iso2: 'SS', dial: '211', flag: '🇸🇸'),
  KPhoneCountry(name: 'Cameroon', iso2: 'CM', dial: '237', flag: '🇨🇲'),
  KPhoneCountry(name: 'Ivory Coast', iso2: 'CI', dial: '225', flag: '🇨🇮'),
  KPhoneCountry(name: 'Senegal', iso2: 'SN', dial: '221', flag: '🇸🇳'),
  KPhoneCountry(name: 'Mali', iso2: 'ML', dial: '223', flag: '🇲🇱'),
  KPhoneCountry(name: 'Niger', iso2: 'NE', dial: '227', flag: '🇳🇪'),
  KPhoneCountry(name: 'Chad', iso2: 'TD', dial: '235', flag: '🇹🇩'),
  KPhoneCountry(name: 'Burkina Faso', iso2: 'BF', dial: '226', flag: '🇧🇫'),
  KPhoneCountry(name: 'Benin', iso2: 'BJ', dial: '229', flag: '🇧🇯'),
  KPhoneCountry(name: 'Togo', iso2: 'TG', dial: '228', flag: '🇹🇬'),
  KPhoneCountry(name: 'Sierra Leone', iso2: 'SL', dial: '232', flag: '🇸🇱'),
  KPhoneCountry(name: 'Liberia', iso2: 'LR', dial: '231', flag: '🇱🇷'),
  KPhoneCountry(name: 'Guinea', iso2: 'GN', dial: '224', flag: '🇬🇳'),
  KPhoneCountry(name: 'Guinea-Bissau', iso2: 'GW', dial: '245', flag: '🇬🇼'),
  KPhoneCountry(name: 'Gambia', iso2: 'GM', dial: '220', flag: '🇬🇲'),
  KPhoneCountry(name: 'Mauritania', iso2: 'MR', dial: '222', flag: '🇲🇷'),
  KPhoneCountry(name: 'Cape Verde', iso2: 'CV', dial: '238', flag: '🇨🇻'),
  KPhoneCountry(name: 'Central African Republic', iso2: 'CF', dial: '236', flag: '🇨🇫'),
  KPhoneCountry(name: 'Republic of the Congo', iso2: 'CG', dial: '242', flag: '🇨🇬'),
  KPhoneCountry(name: 'DR Congo', iso2: 'CD', dial: '243', flag: '🇨🇩'),
  KPhoneCountry(name: 'Gabon', iso2: 'GA', dial: '241', flag: '🇬🇦'),
  KPhoneCountry(name: 'Equatorial Guinea', iso2: 'GQ', dial: '240', flag: '🇬🇶'),
  KPhoneCountry(name: 'Angola', iso2: 'AO', dial: '244', flag: '🇦🇴'),
  KPhoneCountry(name: 'Zambia', iso2: 'ZM', dial: '260', flag: '🇿🇲'),
  KPhoneCountry(name: 'Zimbabwe', iso2: 'ZW', dial: '263', flag: '🇿🇼'),
  KPhoneCountry(name: 'Botswana', iso2: 'BW', dial: '267', flag: '🇧🇼'),
  KPhoneCountry(name: 'Namibia', iso2: 'NA', dial: '264', flag: '🇳🇦'),
  KPhoneCountry(name: 'Mozambique', iso2: 'MZ', dial: '258', flag: '🇲🇿'),
  KPhoneCountry(name: 'Malawi', iso2: 'MW', dial: '265', flag: '🇲🇼'),
  KPhoneCountry(name: 'Rwanda', iso2: 'RW', dial: '250', flag: '🇷🇼'),
  KPhoneCountry(name: 'Burundi', iso2: 'BI', dial: '257', flag: '🇧🇮'),
  KPhoneCountry(name: 'Somalia', iso2: 'SO', dial: '252', flag: '🇸🇴'),
  KPhoneCountry(name: 'Djibouti', iso2: 'DJ', dial: '253', flag: '🇩🇯'),
  KPhoneCountry(name: 'Eritrea', iso2: 'ER', dial: '291', flag: '🇪🇷'),
  KPhoneCountry(name: 'Lesotho', iso2: 'LS', dial: '266', flag: '🇱🇸'),
  KPhoneCountry(name: 'Eswatini', iso2: 'SZ', dial: '268', flag: '🇸🇿'),
  KPhoneCountry(name: 'Madagascar', iso2: 'MG', dial: '261', flag: '🇲🇬'),
  KPhoneCountry(name: 'Mauritius', iso2: 'MU', dial: '230', flag: '🇲🇺'),
  KPhoneCountry(name: 'Seychelles', iso2: 'SC', dial: '248', flag: '🇸🇨'),
  KPhoneCountry(name: 'Comoros', iso2: 'KM', dial: '269', flag: '🇰🇲'),
  KPhoneCountry(name: 'Sao Tome and Principe', iso2: 'ST', dial: '239', flag: '🇸🇹'),
  KPhoneCountry(name: 'Saudi Arabia', iso2: 'SA', dial: '966', flag: '🇸🇦'),
  KPhoneCountry(name: 'United Arab Emirates', iso2: 'AE', dial: '971', flag: '🇦🇪'),
  KPhoneCountry(name: 'Qatar', iso2: 'QA', dial: '974', flag: '🇶🇦'),
  KPhoneCountry(name: 'Kuwait', iso2: 'KW', dial: '965', flag: '🇰🇼'),
  KPhoneCountry(name: 'Bahrain', iso2: 'BH', dial: '973', flag: '🇧🇭'),
  KPhoneCountry(name: 'Oman', iso2: 'OM', dial: '968', flag: '🇴🇲'),
  KPhoneCountry(name: 'Jordan', iso2: 'JO', dial: '962', flag: '🇯🇴'),
  KPhoneCountry(name: 'Lebanon', iso2: 'LB', dial: '961', flag: '🇱🇧'),
  KPhoneCountry(name: 'Israel', iso2: 'IL', dial: '972', flag: '🇮🇱'),
  KPhoneCountry(name: 'Palestine', iso2: 'PS', dial: '970', flag: '🇵🇸'),
  KPhoneCountry(name: 'Iraq', iso2: 'IQ', dial: '964', flag: '🇮🇶'),
  KPhoneCountry(name: 'Iran', iso2: 'IR', dial: '98', flag: '🇮🇷'),
  KPhoneCountry(name: 'Syria', iso2: 'SY', dial: '963', flag: '🇸🇾'),
  KPhoneCountry(name: 'Yemen', iso2: 'YE', dial: '967', flag: '🇾🇪'),
  KPhoneCountry(name: 'Turkey', iso2: 'TR', dial: '90', flag: '🇹🇷'),
  KPhoneCountry(name: 'China', iso2: 'CN', dial: '86', flag: '🇨🇳'),
  KPhoneCountry(name: 'Japan', iso2: 'JP', dial: '81', flag: '🇯🇵'),
  KPhoneCountry(name: 'South Korea', iso2: 'KR', dial: '82', flag: '🇰🇷'),
  KPhoneCountry(name: 'North Korea', iso2: 'KP', dial: '850', flag: '🇰🇵'),
  KPhoneCountry(name: 'India', iso2: 'IN', dial: '91', flag: '🇮🇳'),
  KPhoneCountry(name: 'Pakistan', iso2: 'PK', dial: '92', flag: '🇵🇰'),
  KPhoneCountry(name: 'Bangladesh', iso2: 'BD', dial: '880', flag: '🇧🇩'),
  KPhoneCountry(name: 'Sri Lanka', iso2: 'LK', dial: '94', flag: '🇱🇰'),
  KPhoneCountry(name: 'Nepal', iso2: 'NP', dial: '977', flag: '🇳🇵'),
  KPhoneCountry(name: 'Bhutan', iso2: 'BT', dial: '975', flag: '🇧🇹'),
  KPhoneCountry(name: 'Maldives', iso2: 'MV', dial: '960', flag: '🇲🇻'),
  KPhoneCountry(name: 'Afghanistan', iso2: 'AF', dial: '93', flag: '🇦🇫'),
  KPhoneCountry(name: 'Myanmar', iso2: 'MM', dial: '95', flag: '🇲🇲'),
  KPhoneCountry(name: 'Thailand', iso2: 'TH', dial: '66', flag: '🇹🇭'),
  KPhoneCountry(name: 'Vietnam', iso2: 'VN', dial: '84', flag: '🇻🇳'),
  KPhoneCountry(name: 'Cambodia', iso2: 'KH', dial: '855', flag: '🇰🇭'),
  KPhoneCountry(name: 'Laos', iso2: 'LA', dial: '856', flag: '🇱🇦'),
  KPhoneCountry(name: 'Malaysia', iso2: 'MY', dial: '60', flag: '🇲🇾'),
  KPhoneCountry(name: 'Singapore', iso2: 'SG', dial: '65', flag: '🇸🇬'),
  KPhoneCountry(name: 'Indonesia', iso2: 'ID', dial: '62', flag: '🇮🇩'),
  KPhoneCountry(name: 'Philippines', iso2: 'PH', dial: '63', flag: '🇵🇭'),
  KPhoneCountry(name: 'Brunei', iso2: 'BN', dial: '673', flag: '🇧🇳'),
  KPhoneCountry(name: 'Mongolia', iso2: 'MN', dial: '976', flag: '🇲🇳'),
  KPhoneCountry(name: 'Kazakhstan', iso2: 'KZ', dial: '7', flag: '🇰🇿'),
  KPhoneCountry(name: 'Uzbekistan', iso2: 'UZ', dial: '998', flag: '🇺🇿'),
  KPhoneCountry(name: 'Turkmenistan', iso2: 'TM', dial: '993', flag: '🇹🇲'),
  KPhoneCountry(name: 'Tajikistan', iso2: 'TJ', dial: '992', flag: '🇹🇯'),
  KPhoneCountry(name: 'Kyrgyzstan', iso2: 'KG', dial: '996', flag: '🇰🇬'),
  KPhoneCountry(name: 'Taiwan', iso2: 'TW', dial: '886', flag: '🇹🇼'),
  KPhoneCountry(name: 'Hong Kong', iso2: 'HK', dial: '852', flag: '🇭🇰'),
  KPhoneCountry(name: 'Macau', iso2: 'MO', dial: '853', flag: '🇲🇴'),
  KPhoneCountry(name: 'United Kingdom', iso2: 'GB', dial: '44', flag: '🇬🇧'),
  KPhoneCountry(name: 'Ireland', iso2: 'IE', dial: '353', flag: '🇮🇪'),
  KPhoneCountry(name: 'France', iso2: 'FR', dial: '33', flag: '🇫🇷'),
  KPhoneCountry(name: 'Germany', iso2: 'DE', dial: '49', flag: '🇩🇪'),
  KPhoneCountry(name: 'Spain', iso2: 'ES', dial: '34', flag: '🇪🇸'),
  KPhoneCountry(name: 'Portugal', iso2: 'PT', dial: '351', flag: '🇵🇹'),
  KPhoneCountry(name: 'Italy', iso2: 'IT', dial: '39', flag: '🇮🇹'),
  KPhoneCountry(name: 'Netherlands', iso2: 'NL', dial: '31', flag: '🇳🇱'),
  KPhoneCountry(name: 'Belgium', iso2: 'BE', dial: '32', flag: '🇧🇪'),
  KPhoneCountry(name: 'Luxembourg', iso2: 'LU', dial: '352', flag: '🇱🇺'),
  KPhoneCountry(name: 'Switzerland', iso2: 'CH', dial: '41', flag: '🇨🇭'),
  KPhoneCountry(name: 'Austria', iso2: 'AT', dial: '43', flag: '🇦🇹'),
  KPhoneCountry(name: 'Sweden', iso2: 'SE', dial: '46', flag: '🇸🇪'),
  KPhoneCountry(name: 'Norway', iso2: 'NO', dial: '47', flag: '🇳🇴'),
  KPhoneCountry(name: 'Denmark', iso2: 'DK', dial: '45', flag: '🇩🇰'),
  KPhoneCountry(name: 'Finland', iso2: 'FI', dial: '358', flag: '🇫🇮'),
  KPhoneCountry(name: 'Iceland', iso2: 'IS', dial: '354', flag: '🇮🇸'),
  KPhoneCountry(name: 'Poland', iso2: 'PL', dial: '48', flag: '🇵🇱'),
  KPhoneCountry(name: 'Czech Republic', iso2: 'CZ', dial: '420', flag: '🇨🇿'),
  KPhoneCountry(name: 'Slovakia', iso2: 'SK', dial: '421', flag: '🇸🇰'),
  KPhoneCountry(name: 'Hungary', iso2: 'HU', dial: '36', flag: '🇭🇺'),
  KPhoneCountry(name: 'Romania', iso2: 'RO', dial: '40', flag: '🇷🇴'),
  KPhoneCountry(name: 'Bulgaria', iso2: 'BG', dial: '359', flag: '🇧🇬'),
  KPhoneCountry(name: 'Greece', iso2: 'GR', dial: '30', flag: '🇬🇷'),
  KPhoneCountry(name: 'Croatia', iso2: 'HR', dial: '385', flag: '🇭🇷'),
  KPhoneCountry(name: 'Slovenia', iso2: 'SI', dial: '386', flag: '🇸🇮'),
  KPhoneCountry(name: 'Serbia', iso2: 'RS', dial: '381', flag: '🇷🇸'),
  KPhoneCountry(name: 'Bosnia and Herzegovina', iso2: 'BA', dial: '387', flag: '🇧🇦'),
  KPhoneCountry(name: 'Montenegro', iso2: 'ME', dial: '382', flag: '🇲🇪'),
  KPhoneCountry(name: 'North Macedonia', iso2: 'MK', dial: '389', flag: '🇲🇰'),
  KPhoneCountry(name: 'Albania', iso2: 'AL', dial: '355', flag: '🇦🇱'),
  KPhoneCountry(name: 'Kosovo', iso2: 'XK', dial: '383', flag: '🇽🇰'),
  KPhoneCountry(name: 'Ukraine', iso2: 'UA', dial: '380', flag: '🇺🇦'),
  KPhoneCountry(name: 'Belarus', iso2: 'BY', dial: '375', flag: '🇧🇾'),
  KPhoneCountry(name: 'Moldova', iso2: 'MD', dial: '373', flag: '🇲🇩'),
  KPhoneCountry(name: 'Russia', iso2: 'RU', dial: '7', flag: '🇷🇺'),
  KPhoneCountry(name: 'Estonia', iso2: 'EE', dial: '372', flag: '🇪🇪'),
  KPhoneCountry(name: 'Latvia', iso2: 'LV', dial: '371', flag: '🇱🇻'),
  KPhoneCountry(name: 'Lithuania', iso2: 'LT', dial: '370', flag: '🇱🇹'),
  KPhoneCountry(name: 'Malta', iso2: 'MT', dial: '356', flag: '🇲🇹'),
  KPhoneCountry(name: 'Cyprus', iso2: 'CY', dial: '357', flag: '🇨🇾'),
  KPhoneCountry(name: 'Monaco', iso2: 'MC', dial: '377', flag: '🇲🇨'),
  KPhoneCountry(name: 'Andorra', iso2: 'AD', dial: '376', flag: '🇦🇩'),
  KPhoneCountry(name: 'San Marino', iso2: 'SM', dial: '378', flag: '🇸🇲'),
  KPhoneCountry(name: 'Vatican City', iso2: 'VA', dial: '379', flag: '🇻🇦'),
  KPhoneCountry(name: 'Liechtenstein', iso2: 'LI', dial: '423', flag: '🇱🇮'),
  KPhoneCountry(name: 'Georgia', iso2: 'GE', dial: '995', flag: '🇬🇪'),
  KPhoneCountry(name: 'Armenia', iso2: 'AM', dial: '374', flag: '🇦🇲'),
  KPhoneCountry(name: 'Azerbaijan', iso2: 'AZ', dial: '994', flag: '🇦🇿'),
  KPhoneCountry(name: 'United States', iso2: 'US', dial: '1', flag: '🇺🇸'),
  KPhoneCountry(name: 'Canada', iso2: 'CA', dial: '1', flag: '🇨🇦'),
  KPhoneCountry(name: 'Mexico', iso2: 'MX', dial: '52', flag: '🇲🇽'),
  KPhoneCountry(name: 'Brazil', iso2: 'BR', dial: '55', flag: '🇧🇷'),
  KPhoneCountry(name: 'Argentina', iso2: 'AR', dial: '54', flag: '🇦🇷'),
  KPhoneCountry(name: 'Chile', iso2: 'CL', dial: '56', flag: '🇨🇱'),
  KPhoneCountry(name: 'Colombia', iso2: 'CO', dial: '57', flag: '🇨🇴'),
  KPhoneCountry(name: 'Peru', iso2: 'PE', dial: '51', flag: '🇵🇪'),
  KPhoneCountry(name: 'Venezuela', iso2: 'VE', dial: '58', flag: '🇻🇪'),
  KPhoneCountry(name: 'Ecuador', iso2: 'EC', dial: '593', flag: '🇪🇨'),
  KPhoneCountry(name: 'Bolivia', iso2: 'BO', dial: '591', flag: '🇧🇴'),
  KPhoneCountry(name: 'Paraguay', iso2: 'PY', dial: '595', flag: '🇵🇾'),
  KPhoneCountry(name: 'Uruguay', iso2: 'UY', dial: '598', flag: '🇺🇾'),
  KPhoneCountry(name: 'Guyana', iso2: 'GY', dial: '592', flag: '🇬🇾'),
  KPhoneCountry(name: 'Suriname', iso2: 'SR', dial: '597', flag: '🇸🇷'),
  KPhoneCountry(name: 'Panama', iso2: 'PA', dial: '507', flag: '🇵🇦'),
  KPhoneCountry(name: 'Costa Rica', iso2: 'CR', dial: '506', flag: '🇨🇷'),
  KPhoneCountry(name: 'Nicaragua', iso2: 'NI', dial: '505', flag: '🇳🇮'),
  KPhoneCountry(name: 'Honduras', iso2: 'HN', dial: '504', flag: '🇭🇳'),
  KPhoneCountry(name: 'El Salvador', iso2: 'SV', dial: '503', flag: '🇸🇻'),
  KPhoneCountry(name: 'Guatemala', iso2: 'GT', dial: '502', flag: '🇬🇹'),
  KPhoneCountry(name: 'Belize', iso2: 'BZ', dial: '501', flag: '🇧🇿'),
  KPhoneCountry(name: 'Cuba', iso2: 'CU', dial: '53', flag: '🇨🇺'),
  KPhoneCountry(name: 'Jamaica', iso2: 'JM', dial: '1876', flag: '🇯🇲'),
  KPhoneCountry(name: 'Haiti', iso2: 'HT', dial: '509', flag: '🇭🇹'),
  KPhoneCountry(name: 'Dominican Republic', iso2: 'DO', dial: '1809', flag: '🇩🇴'),
  KPhoneCountry(name: 'Trinidad and Tobago', iso2: 'TT', dial: '1868', flag: '🇹🇹'),
  KPhoneCountry(name: 'Bahamas', iso2: 'BS', dial: '1242', flag: '🇧🇸'),
  KPhoneCountry(name: 'Barbados', iso2: 'BB', dial: '1246', flag: '🇧🇧'),
  KPhoneCountry(name: 'Australia', iso2: 'AU', dial: '61', flag: '🇦🇺'),
  KPhoneCountry(name: 'New Zealand', iso2: 'NZ', dial: '64', flag: '🇳🇿'),
  KPhoneCountry(name: 'Fiji', iso2: 'FJ', dial: '679', flag: '🇫🇯'),
  KPhoneCountry(name: 'Papua New Guinea', iso2: 'PG', dial: '675', flag: '🇵🇬'),
  KPhoneCountry(name: 'Samoa', iso2: 'WS', dial: '685', flag: '🇼🇸'),
  KPhoneCountry(name: 'Tonga', iso2: 'TO', dial: '676', flag: '🇹🇴'),
  KPhoneCountry(name: 'Vanuatu', iso2: 'VU', dial: '678', flag: '🇻🇺'),
  KPhoneCountry(name: 'Solomon Islands', iso2: 'SB', dial: '677', flag: '🇸🇧'),
];

/// Nigeria (+234) — this screen's default phone-country selection.
final KPhoneCountry kDefaultPhoneCountry =
    kPhoneCountries.firstWhere((c) => c.iso2 == 'NG');

/// Nigeria's 36 states + the Federal Capital Territory — hardcoded, static,
/// alphabetical. Matches KycSubmission.state's documented contract
/// (Kudimata-Securities-Backend .pipeline/registry.json): "Nigerian state of
/// residence ... picked from a fixed 36-state+FCT dropdown on the client,
/// not free text." No backend endpoint exists (or is needed) for this list
/// — same "static/keep local" pattern this app already uses for content
/// like the legal document titles.
const List<String> kNigerianStates = [
  'Abia',
  'Adamawa',
  'Akwa Ibom',
  'Anambra',
  'Bauchi',
  'Bayelsa',
  'Benue',
  'Borno',
  'Cross River',
  'Delta',
  'Ebonyi',
  'Edo',
  'Ekiti',
  'Enugu',
  'Gombe',
  'Imo',
  'Jigawa',
  'Kaduna',
  'Kano',
  'Katsina',
  'Kebbi',
  'Kogi',
  'Kwara',
  'Lagos',
  'Nasarawa',
  'Niger',
  'Ogun',
  'Ondo',
  'Osun',
  'Oyo',
  'Plateau',
  'Rivers',
  'Sokoto',
  'Taraba',
  'Yobe',
  'Zamfara',
  'Federal Capital Territory (Abuja)',
];

/// Opens a searchable [showKSheet] listing [kNigerianStates]; returns the
/// tapped state, or null if the sheet is dismissed without a selection.
Future<String?> showStatePicker(BuildContext context, {String? selected}) {
  return showKSheet<String>(
    context,
    title: 'State of residence',
    child: _StatePickerSheet(selected: selected),
  );
}

/// Opens a searchable [showKSheet] listing [kPhoneCountries]; returns the
/// tapped country, or null if the sheet is dismissed without a selection.
Future<KPhoneCountry?> showCountryCodePicker(
  BuildContext context, {
  KPhoneCountry? selected,
}) {
  return showKSheet<KPhoneCountry>(
    context,
    title: 'Country code',
    child: _CountryCodePickerSheet(selected: selected),
  );
}

class _StatePickerSheet extends StatefulWidget {
  const _StatePickerSheet({this.selected});
  final String? selected;

  @override
  State<_StatePickerSheet> createState() => _StatePickerSheetState();
}

class _StatePickerSheetState extends State<_StatePickerSheet> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.trim().toLowerCase();
    final states = q.isEmpty
        ? kNigerianStates
        : kNigerianStates.where((s) => s.toLowerCase().contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KSearchPill(
          placeholder: 'Search states',
          controller: _query,
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 16),
        if (states.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No states match "$_filter".', style: KType.body(color: KColor.ink3)),
          )
        else
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < states.length; i++)
                  _PickerRow(
                    label: states[i],
                    selected: states[i] == widget.selected,
                    first: i == 0,
                    onTap: () => Navigator.of(context).pop(states[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CountryCodePickerSheet extends StatefulWidget {
  const _CountryCodePickerSheet({this.selected});
  final KPhoneCountry? selected;

  @override
  State<_CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<_CountryCodePickerSheet> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.trim().toLowerCase();
    final countries = q.isEmpty
        ? kPhoneCountries
        : kPhoneCountries
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.dial.contains(q) ||
                c.iso2.toLowerCase() == q)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KSearchPill(
          placeholder: 'Search countries or codes',
          controller: _query,
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 16),
        if (countries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No countries match "$_filter".', style: KType.body(color: KColor.ink3)),
          )
        else
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < countries.length; i++)
                  _PickerRow(
                    leading: countries[i].flag,
                    label: countries[i].name,
                    trailingLabel: countries[i].dialLabel,
                    selected: countries[i].iso2 == widget.selected?.iso2,
                    first: i == 0,
                    onTap: () => Navigator.of(context).pop(countries[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One selectable row — mirrors bank_accounts_screen.dart's
/// `_BankOptionRow` exactly (padding, hairline top border on all but the
/// first row, trailing check mark on the selected row) so both pickers read
/// as the same interaction as the rest of the app's picker sheets.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.first,
    required this.onTap,
    this.leading,
    this.trailingLabel,
  });

  final String label;
  final bool selected;
  final bool first;
  final VoidCallback onTap;
  final String? leading;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Text(leading!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(label, style: KType.cardTitle())),
            if (trailingLabel != null) ...[
              Text(trailingLabel!,
                  style: KType.body(color: KColor.ink3, w: KWeight.medium).tnum),
              const SizedBox(width: 10),
            ],
            if (selected) const KIcon('check', size: 18),
          ],
        ),
      ),
    );
  }
}

/// Opens a [showKSheet] listing UserRepository.avatarKeys as a tappable
/// grid, plus a "No avatar" option — added 2026-08-24 (direct product
/// instruction: avatars used to be auto-assigned by hashing the investor's
/// email, with no user choice at all). Used both by the onboarding step
/// right after sign-up and by personal_info_screen.dart's "Avatar" row, so
/// the choice is available both at signup and to change later. Returns the
/// tapped avatar key, the literal 'none' for "no avatar, just my name", or
/// null if the sheet is dismissed without a choice.
Future<String?> showAvatarPicker(BuildContext context, {String? selected}) {
  return showKSheet<String>(
    context,
    title: 'Choose an avatar',
    child: _AvatarPickerSheet(selected: selected),
  );
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Pick a character to represent you across the app, or skip and we'll just show your name.",
          style: KType.body(color: KColor.ink3),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final key in UserRepository.avatarKeys)
              _AvatarChoice(
                avatarKey: key,
                selected: selected == key,
                onTap: () => Navigator.of(context).pop(key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PickerRow(
            label: 'No avatar — just my name',
            selected: selected == null || selected == 'none',
            first: true,
            onTap: () => Navigator.of(context).pop('none'),
          ),
        ),
      ],
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({required this.avatarKey, required this.selected, required this.onTap});
  final String avatarKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? KColor.indicator : Colors.transparent,
            width: 2,
          ),
        ),
        child: KAvatar(avatarKey: avatarKey, size: 64),
      ),
    );
  }
}
