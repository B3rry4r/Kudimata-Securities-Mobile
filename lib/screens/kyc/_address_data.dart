// KYC address step (s17 "Where do you live?") — Nigerian state + LGA
// dataset and their two searchable picker sheets. Screen-local to kyc/,
// entirely owned by utility_bill.dart; NOT imported from
// onboarding/_pickers.dart's own (separately-owned) `kNigerianStates` /
// `showStatePicker` — this codebase's established convention is to
// duplicate a small dataset+sheet per owning screen rather than reach into
// another screen's private file (see onboarding/_pickers.dart's own header
// comment: "lib/widgets/ is FROZEN... file-local... rather than in the
// shared widget library").
//
// LGA data has no shared source anywhere in the app (grepped — none), so
// it's hand-curated here: Nigeria's 36 states + FCT, each with its real,
// standard Local Government Areas (774 nationwide). Same "static, well-known
// dataset, no backend endpoint needed" pattern onboarding/_pickers.dart's
// phone country-code list already documents for itself.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const List<String> kAddressStates = [
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

/// Local Government Areas per state, keyed EXACTLY by [kAddressStates]'
/// entries. Every key above has a real, non-empty list.
const Map<String, List<String>> kLgasByState = {
  'Abia': [
    'Aba North', 'Aba South', 'Arochukwu', 'Bende', 'Ikwuano',
    'Isiala Ngwa North', 'Isiala Ngwa South', 'Isuikwuato', 'Obi Ngwa',
    'Ohafia', 'Osisioma', 'Ugwunagbo', 'Ukwa East', 'Ukwa West',
    'Umuahia North', 'Umuahia South', "Umu Nneochi",
  ],
  'Adamawa': [
    'Demsa', 'Fufure', 'Ganye', 'Gayuk', 'Gombi', 'Grie', 'Hong', 'Jada',
    'Lamurde', 'Madagali', 'Maiha', 'Mayo Belwa', 'Michika', 'Mubi North',
    'Mubi South', 'Numan', 'Shelleng', 'Song', 'Toungo', 'Yola North',
    'Yola South',
  ],
  'Akwa Ibom': [
    'Abak', 'Eastern Obolo', 'Eket', 'Esit Eket', 'Essien Udim',
    'Etim Ekpo', 'Etinan', 'Ibeno', 'Ibesikpo Asutan', 'Ibiono Ibom', 'Ika',
    'Ikono', 'Ikot Abasi', 'Ikot Ekpene', 'Ini', 'Itu', 'Mbo',
    'Mkpat Enin', 'Nsit Atai', 'Nsit Ibom', 'Nsit Ubium', 'Obot Akara',
    'Okobo', 'Onna', 'Oron', 'Oruk Anam', 'Udung Uko', 'Ukanafun', 'Uruan',
    'Urue-Offong/Oruko', 'Uyo',
  ],
  'Anambra': [
    'Aguata', 'Anambra East', 'Anambra West', 'Anaocha', 'Awka North',
    'Awka South', 'Ayamelum', 'Dunukofia', 'Ekwusigo', 'Idemili North',
    'Idemili South', 'Ihiala', 'Njikoka', 'Nnewi North', 'Nnewi South',
    'Ogbaru', 'Onitsha North', 'Onitsha South', 'Orumba North',
    'Orumba South', 'Oyi',
  ],
  'Bauchi': [
    'Alkaleri', 'Bauchi', 'Bogoro', 'Damban', 'Darazo', 'Dass', 'Gamawa',
    'Ganjuwa', 'Giade', "Itas/Gadau", "Jama'are", 'Katagum', 'Kirfi',
    'Misau', 'Ningi', 'Shira', 'Tafawa Balewa', 'Toro', 'Warji', 'Zaki',
  ],
  'Bayelsa': [
    'Brass', 'Ekeremor', 'Kolokuma/Opokuma', 'Nembe', 'Ogbia', 'Sagbama',
    'Southern Ijaw', 'Yenagoa',
  ],
  'Benue': [
    'Ado', 'Agatu', 'Apa', 'Buruku', 'Gboko', 'Guma', 'Gwer East',
    'Gwer West', 'Katsina-Ala', 'Konshisha', 'Kwande', 'Logo', 'Makurdi',
    'Obi', 'Ogbadibo', 'Ohimini', 'Oju', 'Okpokwu', 'Otukpo', 'Tarka',
    'Ukum', 'Ushongo', 'Vandeikya',
  ],
  'Borno': [
    'Abadam', 'Askira/Uba', 'Bama', 'Bayo', 'Biu', 'Chibok', 'Damboa',
    'Dikwa', 'Gubio', 'Guzamala', 'Gwoza', 'Hawul', 'Jere', 'Kaga',
    'Kala/Balge', 'Konduga', 'Kukawa', 'Kwaya Kusar', 'Mafa', 'Magumeri',
    'Maiduguri', 'Marte', 'Mobbar', 'Monguno', 'Ngala', 'Nganzai', 'Shani',
  ],
  'Cross River': [
    'Abi', 'Akamkpa', 'Akpabuyo', 'Bakassi', 'Bekwarra', 'Biase', 'Boki',
    'Calabar Municipal', 'Calabar South', 'Etung', 'Ikom', 'Obanliku',
    'Obubra', 'Obudu', 'Odukpani', 'Ogoja', 'Yakuur', 'Yala',
  ],
  'Delta': [
    'Aniocha North', 'Aniocha South', 'Bomadi', 'Burutu', 'Ethiope East',
    'Ethiope West', 'Ika North East', 'Ika South', 'Isoko North',
    'Isoko South', 'Ndokwa East', 'Ndokwa West', 'Okpe', 'Oshimili North',
    'Oshimili South', 'Patani', 'Sapele', 'Udu', 'Ughelli North',
    'Ughelli South', 'Ukwuani', 'Uvwie', 'Warri North', 'Warri South',
    'Warri South West',
  ],
  'Ebonyi': [
    'Abakaliki', 'Afikpo North', 'Afikpo South', 'Ebonyi', 'Ezza North',
    'Ezza South', 'Ikwo', 'Ishielu', 'Ivo', 'Izzi', 'Ohaozara', 'Ohaukwu',
    'Onicha',
  ],
  'Edo': [
    'Akoko-Edo', 'Egor', 'Esan Central', 'Esan North-East',
    'Esan South-East', 'Esan West', 'Etsako Central', 'Etsako East',
    'Etsako West', 'Igueben', 'Ikpoba Okha', 'Oredo', 'Orhionmwon',
    'Ovia North-East', 'Ovia South-West', 'Owan East', 'Owan West',
    'Uhunmwonde',
  ],
  'Ekiti': [
    'Ado Ekiti', 'Efon', 'Ekiti East', 'Ekiti South-West', 'Ekiti West',
    'Emure', 'Gbonyin', 'Ido Osi', 'Ijero', 'Ikere', 'Ikole', 'Ilejemeje',
    'Irepodun/Ifelodun', 'Ise/Orun', 'Moba', 'Oye',
  ],
  'Enugu': [
    'Aninri', 'Awgu', 'Enugu East', 'Enugu North', 'Enugu South',
    'Ezeagu', 'Igbo Etiti', 'Igbo Eze North', 'Igbo Eze South', 'Isi Uzo',
    'Nkanu East', 'Nkanu West', 'Nsukka', 'Oji River', 'Udenu', 'Udi',
    'Uzo Uwani',
  ],
  'Gombe': [
    'Akko', 'Balanga', 'Billiri', 'Dukku', 'Funakaye', 'Gombe', 'Kaltungo',
    'Kwami', 'Nafada', 'Shongom', 'Yamaltu/Deba',
  ],
  'Imo': [
    'Aboh Mbaise', 'Ahiazu Mbaise', 'Ehime Mbano', 'Ezinihitte',
    'Ideato North', 'Ideato South', 'Ihitte/Uboma', 'Ikeduru',
    'Isiala Mbano', 'Isu', 'Mbaitoli', 'Ngor Okpala', 'Njaba', 'Nkwerre',
    'Nwangele', 'Obowo', 'Oguta', 'Ohaji/Egbema', 'Okigwe', 'Onuimo',
    'Orlu', 'Orsu', 'Oru East', 'Oru West', 'Owerri Municipal',
    'Owerri North', 'Owerri West',
  ],
  'Jigawa': [
    'Auyo', 'Babura', 'Biriniwa', 'Birnin Kudu', 'Buji', 'Dutse',
    'Gagarawa', 'Garki', 'Gumel', 'Guri', 'Gwaram', 'Gwiwa', 'Hadejia',
    'Jahun', 'Kafin Hausa', 'Kaugama', 'Kazaure', 'Kiri Kasama', 'Kiyawa',
    'Maigatari', 'Malam Madori', 'Miga', 'Ringim', 'Roni',
    'Sule Tankarkar', 'Taura', 'Yankwashi',
  ],
  'Kaduna': [
    'Birnin Gwari', 'Chikun', 'Giwa', 'Igabi', 'Ikara', 'Jaba', "Jema'a",
    'Kachia', 'Kaduna North', 'Kaduna South', 'Kagarko', 'Kajuru', 'Kaura',
    'Kauru', 'Kubau', 'Kudan', 'Lere', 'Makarfi', 'Sabon Gari', 'Sanga',
    'Soba', 'Zangon Kataf', 'Zaria',
  ],
  'Kano': [
    'Ajingi', 'Albasu', 'Bagwai', 'Bebeji', 'Bichi', 'Bunkure', 'Dala',
    'Dambatta', 'Dawakin Kudu', 'Dawakin Tofa', 'Doguwa', 'Fagge',
    'Gabasawa', 'Garko', 'Garun Mallam', 'Gaya', 'Gezawa', 'Gwale',
    'Gwarzo', 'Kabo', 'Kano Municipal', 'Karaye', 'Kibiya', 'Kiru',
    'Kumbotso', 'Kunchi', 'Kura', 'Madobi', 'Makoda', 'Minjibir',
    'Nasarawa', 'Rano', 'Rimin Gado', 'Rogo', 'Shanono', 'Sumaila',
    'Takai', 'Tarauni', 'Tofa', 'Tsanyawa', 'Tudun Wada', 'Ungogo',
    'Warawa', 'Wudil',
  ],
  'Katsina': [
    'Bakori', 'Batagarawa', 'Batsari', 'Baure', 'Bindawa', 'Charanchi',
    'Dan Musa', 'Dandume', 'Danja', 'Daura', 'Dutsi', "Dutsin-Ma",
    'Faskari', 'Funtua', 'Ingawa', 'Jibia', 'Kafur', 'Kaita', 'Kankara',
    'Kankia', 'Katsina', 'Kurfi', 'Kusada', "Mai'Adua", 'Malumfashi',
    'Mani', 'Mashi', 'Matazu', 'Musawa', 'Rimi', 'Sabuwa', 'Safana',
    'Sandamu', 'Zango',
  ],
  'Kebbi': [
    'Aleiro', 'Arewa Dandi', 'Argungu', 'Augie', 'Bagudo', 'Birnin Kebbi',
    'Bunza', 'Dandi', 'Fakai', 'Gwandu', 'Jega', 'Kalgo', 'Koko/Besse',
    'Maiyama', 'Ngaski', 'Sakaba', 'Shanga', 'Suru', 'Wasagu/Danko',
    'Yauri', 'Zuru',
  ],
  'Kogi': [
    'Adavi', 'Ajaokuta', 'Ankpa', 'Bassa', 'Dekina', 'Ibaji', 'Idah',
    'Igalamela Odolu', 'Ijumu', 'Kabba/Bunu', 'Kogi', 'Lokoja',
    'Mopa Muro', 'Ofu', 'Ogori/Magongo', 'Okehi', 'Okene', 'Olamaboro',
    'Omala', 'Yagba East', 'Yagba West',
  ],
  'Kwara': [
    'Asa', 'Baruten', 'Edu', 'Ekiti', 'Ifelodun', 'Ilorin East',
    'Ilorin South', 'Ilorin West', 'Irepodun', 'Isin', 'Kaiama', 'Moro',
    'Offa', 'Oke Ero', 'Oyun', 'Pategi',
  ],
  'Lagos': [
    'Agege', 'Ajeromi-Ifelodun', 'Alimosho', 'Amuwo-Odofin', 'Apapa',
    'Badagry', 'Epe', 'Eti-Osa', 'Ibeju-Lekki', 'Ifako-Ijaiye', 'Ikeja',
    'Ikorodu', 'Kosofe', 'Lagos Island', 'Lagos Mainland', 'Mushin', 'Ojo',
    'Oshodi-Isolo', 'Shomolu', 'Surulere',
  ],
  'Nasarawa': [
    'Akwanga', 'Awe', 'Doma', 'Karu', 'Keana', 'Keffi', 'Kokona', 'Lafia',
    'Nasarawa', 'Nasarawa Egon', 'Obi', 'Toto', 'Wamba',
  ],
  'Niger': [
    'Agaie', 'Agwara', 'Bida', 'Borgu', 'Bosso', 'Chanchaga', 'Edati',
    'Gbako', 'Gurara', 'Katcha', 'Kontagora', 'Lapai', 'Lavun', 'Magama',
    'Mariga', 'Mashegu', 'Mokwa', 'Moya', 'Paikoro', 'Rafi', 'Rijau',
    'Shiroro', 'Suleja', 'Tafa', 'Wushishi',
  ],
  'Ogun': [
    'Abeokuta North', 'Abeokuta South', 'Ado-Odo/Ota',
    'Egbado North (Yewa North)', 'Egbado South (Yewa South)', 'Ewekoro',
    'Ifo', 'Ijebu East', 'Ijebu North', 'Ijebu North East', 'Ijebu Ode',
    'Ikenne', 'Imeko Afon', 'Ipokia', 'Obafemi Owode', 'Odeda',
    'Odogbolu', 'Ogun Waterside', 'Remo North', 'Shagamu',
  ],
  'Ondo': [
    'Akoko North-East', 'Akoko North-West', 'Akoko South-East',
    'Akoko South-West', 'Akure North', 'Akure South', 'Ese Odo', 'Idanre',
    'Ifedore', 'Ilaje', 'Ile Oluji/Okeigbo', 'Irele', 'Odigbo',
    'Okitipupa', 'Ondo East', 'Ondo West', 'Ose', 'Owo',
  ],
  'Osun': [
    'Aiyedaade', 'Aiyedire', 'Atakunmosa East', 'Atakunmosa West',
    'Boluwaduro', 'Boripe', 'Ede North', 'Ede South', 'Egbedore',
    'Ejigbo', 'Ife Central', 'Ife East', 'Ife North', 'Ife South',
    'Ifedayo', 'Ifelodun', 'Ila', 'Ilesa East', 'Ilesa West', 'Irepodun',
    'Irewole', 'Isokan', 'Iwo', 'Obokun', 'Odo Otin', 'Ola Oluwa',
    'Olorunda', 'Oriade', 'Orolu', 'Osogbo',
  ],
  'Oyo': [
    'Afijio', 'Akinyele', 'Atiba', 'Atisbo', 'Egbeda', 'Ibadan North',
    'Ibadan North-East', 'Ibadan North-West', 'Ibadan South-East',
    'Ibadan South-West', 'Ibarapa Central', 'Ibarapa East',
    'Ibarapa North', 'Ido', 'Irepo', 'Iseyin', 'Itesiwaju', 'Iwajowa',
    'Kajola', 'Lagelu', 'Ogbomosho North', 'Ogbomosho South', 'Ogo Oluwa',
    'Olorunsogo', 'Oluyole', 'Ona Ara', 'Orelope', 'Ori Ire', 'Oyo East',
    'Oyo West', 'Saki East', 'Saki West', 'Surulere',
  ],
  'Plateau': [
    'Barkin Ladi', 'Bassa', 'Bokkos', 'Jos East', 'Jos North', 'Jos South',
    'Kanam', 'Kanke', 'Langtang North', 'Langtang South', 'Mangu',
    'Mikang', 'Pankshin', "Qua'an Pan", 'Riyom', 'Shendam', 'Wase',
  ],
  'Rivers': [
    'Abua/Odual', 'Ahoada East', 'Ahoada West', 'Akuku-Toru', 'Andoni',
    'Asari-Toru', 'Bonny', 'Degema', 'Eleme', 'Emuoha', 'Etche', 'Gokana',
    'Ikwerre', 'Khana', 'Obio/Akpor', 'Ogba/Egbema/Ndoni', 'Ogu/Bolo',
    'Okrika', 'Omuma', 'Opobo/Nkoro', 'Oyigbo', 'Port Harcourt', 'Tai',
  ],
  'Sokoto': [
    'Binji', 'Bodinga', 'Dange Shuni', 'Gada', 'Goronyo', 'Gudu',
    'Gwadabawa', 'Illela', 'Isa', 'Kebbe', 'Kware', 'Rabah', 'Sabon Birni',
    'Shagari', 'Silame', 'Sokoto North', 'Sokoto South', 'Tambuwal',
    'Tangaza', 'Tureta', 'Wamako', 'Wurno', 'Yabo',
  ],
  'Taraba': [
    'Ardo Kola', 'Bali', 'Donga', 'Gashaka', 'Gassol', 'Ibi', 'Jalingo',
    'Karim Lamido', 'Kurmi', 'Lau', 'Sardauna', 'Takum', 'Ussa', 'Wukari',
    'Yorro', 'Zing',
  ],
  'Yobe': [
    'Bade', 'Bursari', 'Damaturu', 'Fika', 'Fune', 'Geidam', 'Gujba',
    'Gulani', 'Jakusko', 'Karasuwa', 'Machina', 'Nangere', 'Nguru',
    'Potiskum', 'Tarmuwa', 'Yunusari', 'Yusufari',
  ],
  'Zamfara': [
    'Anka', 'Bakura', 'Birnin Magaji/Kiyaw', 'Bukkuyum', 'Bungudu',
    'Chafe', 'Gummi', 'Gusau', 'Kaura Namoda', 'Maradun', 'Maru',
    'Shinkafi', 'Talata Mafara', 'Tsafe', 'Zurmi',
  ],
  'Federal Capital Territory (Abuja)': [
    'Abaji', 'Abuja Municipal', 'Bwari', 'Gwagwalada', 'Kuje', 'Kwali',
  ],
};

/// Opens a searchable [showKSheet] listing [kAddressStates]; returns the
/// tapped state, or null if dismissed without a selection.
Future<String?> showAddressStatePicker(BuildContext context, {String? selected}) {
  return showKSheet<String>(
    context,
    title: 'State',
    child: _AddrPickerSheet(
      options: kAddressStates,
      selected: selected,
      searchHint: 'Search states',
    ),
  );
}

/// Opens a searchable [showKSheet] listing [state]'s LGAs (via
/// [kLgasByState]); returns the tapped LGA, or null if dismissed without a
/// selection.
Future<String?> showAddressLgaPicker(
  BuildContext context, {
  required String state,
  String? selected,
}) {
  final lgas = kLgasByState[state] ?? const [];
  return showKSheet<String>(
    context,
    title: 'LGA',
    child: _AddrPickerSheet(
      options: lgas,
      selected: selected,
      searchHint: 'Search LGAs',
    ),
  );
}

class _AddrPickerSheet extends StatefulWidget {
  const _AddrPickerSheet({required this.options, required this.searchHint, this.selected});
  final List<String> options;
  final String searchHint;
  final String? selected;

  @override
  State<_AddrPickerSheet> createState() => _AddrPickerSheetState();
}

class _AddrPickerSheetState extends State<_AddrPickerSheet> {
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
    final options = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KSearchPill(
          placeholder: widget.searchHint,
          controller: _query,
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 16),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No matches for "$_filter".', style: KType.body(color: KColor.ink3)),
          )
        else
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++)
                  _AddrPickerRow(
                    label: options[i],
                    selected: options[i] == widget.selected,
                    first: i == 0,
                    onTap: () => Navigator.of(context).pop(options[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One selectable row — same shape as onboarding/_pickers.dart's own
/// `_PickerRow` (duplicated rather than shared, per that file's own
/// convention note).
class _AddrPickerRow extends StatelessWidget {
  const _AddrPickerRow({
    required this.label,
    required this.selected,
    required this.first,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

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
            Expanded(child: Text(label, style: KType.cardTitle())),
            if (selected) const KIcon('check', size: 18),
          ],
        ),
      ),
    );
  }
}
