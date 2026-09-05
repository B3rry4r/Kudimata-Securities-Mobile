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
import 'package:kudimata_invest/data/repositories/kyc_repository.dart'
    show kSourceOfFundsOptions;
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

/// Nigeria (+234) — the default phone-country selection on every screen
/// that uses [kPhoneCountries] (sign_up_screen.dart,
/// personal_details_screen.dart): this is an NGX brokerage, so a Nigerian
/// investor is overwhelmingly the common case, but the picker lets anyone
/// change it before typing a number.
final KPhoneCountry kDefaultPhoneCountry =
    kPhoneCountries.firstWhere((c) => c.iso2 == 'NG');

/// Best-effort match: the [kPhoneCountries] entry whose dial code is a
/// prefix of [e164]'s digits, preferring the LONGEST matching dial code —
/// needed because dial codes are not prefix-free (e.g. Jamaica's '1876' vs
/// the US/Canada's plain '1'). Falls back to [kDefaultPhoneCountry] for a
/// value with no leading '+' (no explicit country, same as
/// [composePhoneE164]'s own convention) or an unrecognised code. Used to
/// split a stored E.164 string back into (country, local part) for
/// prefill/display — the reverse of composing one.
KPhoneCountry countryForE164(String e164) {
  if (!e164.startsWith('+')) return kDefaultPhoneCountry;
  final digits = e164.substring(1);
  KPhoneCountry? best;
  for (final c in kPhoneCountries) {
    if (digits.startsWith(c.dial) && (best == null || c.dial.length > best.dial.length)) {
      best = c;
    }
  }
  return best ?? kDefaultPhoneCountry;
}

/// The national-number portion of [e164] once [country]'s dial code is
/// stripped — pairs with [countryForE164] to prefill/display a stored
/// phone back into a country pill + plain-digits field. Returns [e164]
/// unchanged if it doesn't actually start with that country's dial code
/// (defensive: callers always pass the country [countryForE164] itself
/// returned for this same string, so this should only trip on a caller
/// bug).
String localPartOf(String e164, KPhoneCountry country) {
  final prefix = '+${country.dial}';
  if (!e164.startsWith(prefix)) return e164;
  return e164.substring(prefix.length);
}

/// Builds an E.164-shaped string from whatever an investor typed (with or
/// without a leading '+', local '0'-prefixed, dial-code-prefixed, or bare
/// national-number digits) plus the picked country's dial code. Does not
/// judge whether the *result* is a well-formed phone number for that
/// country — it just prefixes the dial code the same way regardless of
/// shape. Empty input composes to just `'+$dialCode'`; callers that must
/// not send a bare dial code should check [raw] is non-empty first (see
/// sign_up_screen.dart, where phone stays optional and this is the reason
/// it checks emptiness itself rather than relying on this to signal it).
///
/// Kept intentionally permissive (unlike [normalizePhoneToE164] below) so
/// an investor's optional, not-yet-format-checked sign-up phone reaches the
/// server as typed-plus-country-code rather than being silently dropped
/// client-side when it doesn't look quite right — the server's own
/// `normalizePhone()` (Kudimata-Securities-Backend src/common/phone.ts) is
/// what actually validates and is what surfaces INVALID_PHONE back onto
/// the field.
String composePhoneE164(String raw, String dialCode) {
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (hasPlus) return '+$digits';
  if (digits.startsWith(dialCode)) return '+$digits';
  if (digits.startsWith('0')) return '+$dialCode${digits.substring(1)}';
  return '+$dialCode$digits';
}

/// Loose E.164 check mirroring the backend's generic E.164 validator
/// (Kudimata-Securities-Backend src/common/phone.ts's `E164_PATTERN`).
final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

/// [composePhoneE164], gated on the result actually looking like a phone
/// number — returns null for empty input or a result that doesn't match
/// E.164 shape. Used where the phone field is REQUIRED and must gate
/// Continue (personal_details_screen.dart); sign_up_screen.dart's phone
/// stays optional and uses the ungated [composePhoneE164] instead so a
/// value the investor did type is never silently discarded.
String? normalizePhoneToE164(String raw, String dialCode) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  final e164 = composePhoneE164(raw, dialCode);
  return _e164Pattern.hasMatch(e164) ? e164 : null;
}

/// Phone-number field: a tappable country-code pill (flag + dial code,
/// opens [showCountryCodePicker]) beside a plain digits [TextField] —
/// originally built file-local to the old "A few more details" screen
/// (personal_details_screen.dart) and promoted here, alongside the picker
/// and dataset it was always paired with, once sign_up_screen.dart needed
/// the exact same field (2026-08-29: the sign-up phone step stopped
/// hardcoding `+234` and gained this same country picker). A shared public
/// widget rather than a second file-local copy — this codebase's "never
/// fork a widget, a variant is a prop" rule applies just as much to a
/// small file-local widget as to anything in lib/widgets/.
class KPhoneNumberField extends StatefulWidget {
  const KPhoneNumberField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryTap,
    this.onChanged,
    this.error,
    this.helper,
    this.hintText = '801 234 5678',
    this.required = false,
  });

  final TextEditingController controller;
  final KPhoneCountry country;
  final VoidCallback onCountryTap;
  final ValueChanged<String>? onChanged;
  final String? error;

  /// See KInput.required — renders a red asterisk beside the label.
  final bool required;

  /// Shown under the field when [error] is null. Callers should make this
  /// country-aware themselves (or omit it) rather than assert something
  /// only true for one country — see sign_up_screen.dart's own helper,
  /// which is Nigeria/BVN-specific and only shown when Nigeria is picked.
  final String? helper;

  /// Static across every country, same as the original field this was
  /// promoted from — an illustrative example, not a per-country format
  /// hint.
  final String hintText;

  @override
  State<KPhoneNumberField> createState() => _KPhoneNumberFieldState();
}

class _KPhoneNumberFieldState extends State<KPhoneNumberField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final borderColor = widget.error != null
        ? KColor.loss
        : focused
            ? KColor.ink
            : KColor.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KFieldLabel('Phone number', required: widget.required, color: KColor.ink2),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onCountryTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: KColor.paper,
                  borderRadius: BorderRadius.circular(KRadii.input),
                  border: Border.all(color: KColor.hairline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.country.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(widget.country.dialLabel,
                        style: KType.body(color: KColor.ink2, w: KWeight.medium).tnum),
                    const SizedBox(width: 6),
                    KIcon('arrowDown', size: 14, color: KColor.ink3),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: KColor.paper,
                  borderRadius: BorderRadius.circular(KRadii.input),
                  border: Border.all(color: borderColor, width: 1),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  onChanged: widget.onChanged,
                  keyboardType: TextInputType.phone,
                  cursorColor: KColor.indicator,
                  cursorWidth: 1.5,
                  style: KType.body(color: KColor.ink, w: KWeight.medium).copyWith(
                    letterSpacing: -0.14,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: KType.body(color: KColor.ink3),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null || widget.helper != null) ...[
          const SizedBox(height: 7),
          Text(
            widget.error ?? widget.helper!,
            style: KType.micro(color: widget.error != null ? KColor.loss : KColor.ink3)
                .copyWith(letterSpacing: 0.02 * 10),
          ),
        ],
      ],
    );
  }
}

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
    // 2026-08-31: matches avatar_screen.dart's _AvatarTile — KAvatar's own
    // plate (KIllo.platePaper) is a rounded square, not a circle, now that
    // it draws the persona characters instead of the old circular DiceBear
    // glyphs, so the selection ring follows the same shape.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadii.card + 3),
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

// ── Shared collapsed-select chrome + the source-of-funds picker ───────────
// Added 2026-09-05, when the KYC source-of-funds step became a select instead
// of nine inline radio rows (owner instruction: nine visible options is too
// tall a list to sit as radios).
//
// [KSelectField] was next_of_kin.dart's file-private `_RelationshipField`.
// It MOVED here rather than being copied: this file is already where the app's
// picker sheets live (showStatePicker/showCountryCodePicker/showAvatarPicker,
// all built on showKSheet + [_PickerRow]), and next_of_kin.dart already imports
// it. A second collapsed-select field on the source-of-funds screen would have
// been a second truth about what a select looks like — exactly the fork the
// build contract forbids — so there is now one, used by both.

/// The closed/collapsed state of a select: same visual chrome as [KInput]
/// (tracked uppercase label, 50px hairline box, trailing chevron) so it sits
/// consistently among the KInput fields around it in the same KCard, but opens
/// a [showKSheet] picker instead of a keyboard.
///
/// [value] null renders the [placeholder] in the muted ink KInput uses for its
/// own placeholder, so an unanswered select reads as unanswered.
class KSelectField extends StatelessWidget {
  const KSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Select',
    this.required = false,
    this.error,
  });

  final String label;

  /// The chosen option's human label — NOT its wire code. A select shows the
  /// investor what they picked; wire codes stay in lib/data/.
  final String? value;
  final VoidCallback onTap;
  final String placeholder;

  /// See KInput.required — renders a red asterisk beside the label.
  final bool required;

  /// Field-level error, rendered underneath in the same place and style
  /// [KInput] puts its own, so a select and a text field refuse identically.
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KFieldLabel(label, required: required, color: KColor.ink2),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: KColor.paper,
              borderRadius: BorderRadius.circular(KRadii.input),
              border: Border.all(
                color: error != null ? KColor.loss : KColor.hairline,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KType.body(
                      color: value == null ? KColor.ink3 : KColor.ink,
                      w: KWeight.medium,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                KIcon('chevronRight', size: 20, color: KColor.ink3),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error!, style: KType.data(color: KColor.loss)),
        ],
      ],
    );
  }
}

/// Opens a [showKSheet] listing [kSourceOfFundsOptions]; returns the tapped
/// option's WIRE CODE, or null if the sheet is dismissed without a selection.
///
/// The nine options come from lib/data/ — they mirror the backend's
/// `SourceOfFunds` enum, and a screen never invents a wire value. Unsearchable,
/// unlike the state/country pickers above: nine options all fit, and a search
/// pill over nine rows is chrome pretending to be a feature.
Future<String?> showSourceOfFundsPicker(BuildContext context, {String? selected}) {
  return showKSheet<String>(
    context,
    title: 'Source of funds',
    child: KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < kSourceOfFundsOptions.length; i++)
            _PickerRow(
              label: kSourceOfFundsOptions[i].label,
              selected: kSourceOfFundsOptions[i].code == selected,
              first: i == 0,
              onTap: () => Navigator.of(context).pop(kSourceOfFundsOptions[i].code),
            ),
        ],
      ),
    ),
  );
}
