/// Paramètres fiscaux utilisés par les simulateurs (impôt sur le revenu,
/// IFI, démembrement, donation/succession) — valeurs de référence légales
/// (barèmes, seuils, abattements) qui évoluent d'une année sur l'autre par
/// décision de l'État, contrairement au reste du code qui ne change qu'au
/// rythme des mises à jour du logiciel.
///
/// [defaults] fige les valeurs actuellement connues (celles qui étaient,
/// avant cette fonctionnalité, codées en dur dans chaque calculateur — voir
/// `simulations_taxation_screen.dart`/`simulations_transmission_screen.dart`)
/// : c'est la référence vers laquelle un bouton "Réinitialiser" ramène une
/// valeur modifiée. Persisté par profil comme le reste de l'état des
/// simulateurs (voir `SimulationStateRepository`, clé `'tax_parameters'`),
/// pas par vault : rien n'empêche techniquement deux profils du même foyer
/// de personnaliser ces valeurs différemment, mais en pratique elles
/// reflètent la loi, pas une préférence individuelle.
library;

import '../../core/simulations/simulation_state_repository.dart';

/// Clé de persistance commune aux simulateurs (IR/IFI/transmission) et à
/// l'écran de Réglages "Paramètres fiscaux" — les trois lisent/écrivent le
/// même enregistrement via [SimulationStateRepository], comme n'importe
/// quel autre état de simulateur (voir sa doc de classe).
const _stateKey = 'tax_parameters';

/// Charge les paramètres fiscaux du profil actif — [TaxParameters.defaults]
/// tel quel si l'utilisateur n'a encore rien personnalisé.
Future<TaxParameters> loadTaxParameters(String vaultPath) async {
  final data = await SimulationStateRepository(vaultPath).read(_stateKey);
  if (data.isEmpty) return TaxParameters.defaults;
  return TaxParameters.fromJson(data);
}

Future<void> saveTaxParameters(String vaultPath, TaxParameters params) =>
    SimulationStateRepository(vaultPath).write(_stateKey, params.toJson());

/// Une tranche d'un barème progressif : s'applique jusqu'à [upper] (exclu de
/// la tranche précédente), au taux [rate] (en %, ex : `20` pour 20 %).
/// [upper] vaut `double.infinity` pour la dernière tranche, non plafonnée.
class TaxBracket {
  final double upper;
  final double rate;

  const TaxBracket(this.upper, this.rate);

  factory TaxBracket.fromJson(Map<String, dynamic> json) => TaxBracket(
    (json['upper'] as num?)?.toDouble() ?? double.infinity,
    (json['rate'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    // `double.infinity` n'est pas représentable en JSON standard : encodé
    // comme `null`, réinterprété comme l'infini au décodage (voir
    // `fromJson`) plutôt que de planter `jsonEncode`.
    'upper': upper.isFinite ? upper : null,
    'rate': rate,
  };
}

/// Une tranche du barème de l'usufruit (article 669 CGI) : un usufruitier
/// âgé de [maxAge] ans ou moins a une nue-propriété valorisée à [pctNue] %
/// de la pleine propriété. [maxAge] vaut `null` pour la dernière tranche
/// (au-delà de l'âge le plus élevé du barème, non plafonnée).
class UsufruitBracket {
  final int? maxAge;
  final double pctNue;

  const UsufruitBracket(this.maxAge, this.pctNue);

  factory UsufruitBracket.fromJson(Map<String, dynamic> json) =>
      UsufruitBracket(
        json['maxAge'] as int?,
        (json['pctNue'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'maxAge': maxAge, 'pctNue': pctNue};
}

/// Valeurs par défaut, en identifiants top-level plutôt qu'imbriquées dans
/// [TaxParameters.defaults] : ce sont elles que les paramètres optionnels
/// des fonctions de calcul (`computeIR`, `computeIFI`, `nueProprietePct`,
/// `abattementFor`, `directLineRights`, `spouseRights`) utilisent comme
/// valeur par défaut — un accès à un champ d'instance, même `const`,
/// n'étant pas une expression constante valide en Dart pour ce contexte.
const defaultIrLimits = [11294.0, 28797.0, 82341.0, 177106.0];
const defaultIrRates = [0.0, 11.0, 30.0, 41.0, 45.0];
const defaultIfiLimits = [
  800000.0,
  1300000.0,
  2570000.0,
  5000000.0,
  10000000.0,
];
const defaultIfiRates = [0.0, 0.5, 0.7, 1.0, 1.25, 1.5];
const defaultIfiSeuilImposition = 1300000.0;
const defaultDemembrementBrackets = [
  UsufruitBracket(20, 10),
  UsufruitBracket(30, 20),
  UsufruitBracket(40, 30),
  UsufruitBracket(50, 40),
  UsufruitBracket(60, 50),
  UsufruitBracket(70, 60),
  UsufruitBracket(80, 70),
  UsufruitBracket(90, 80),
  UsufruitBracket(null, 90),
];
const defaultDirectLineBrackets = [
  TaxBracket(8072, 0.05),
  TaxBracket(12109, 0.10),
  TaxBracket(15932, 0.15),
  TaxBracket(552324, 0.20),
  TaxBracket(902838, 0.30),
  TaxBracket(1805677, 0.40),
  TaxBracket(double.infinity, 0.45),
];
const defaultSpouseBrackets = [
  TaxBracket(8072, 0.05),
  TaxBracket(15932, 0.10),
  TaxBracket(31865, 0.15),
  TaxBracket(552324, 0.20),
  TaxBracket(902838, 0.30),
  TaxBracket(1805677, 0.40),
  TaxBracket(double.infinity, 0.45),
];
const defaultAbattementEnfant = 100000.0;
const defaultAbattementPetitEnfant = 31865.0;
const defaultAbattementConjoint = 80724.0;
const defaultPfuIrRate = 12.8;
const defaultPfuPsRate = 18.6;

class TaxParameters {
  /// Barème de l'impôt sur le revenu par part de quotient familial (voir
  /// `computeIR`). [irLimits] a un élément de moins que [irRates] : la
  /// dernière tranche (taux `irRates.last`) n'a pas de plafond.
  final List<double> irLimits;
  final List<double> irRates;

  /// Barème IFI (article 977 CGI, voir `computeIFI`). Même convention que
  /// [irLimits]/[irRates] : [ifiLimits] a un élément de moins que
  /// [ifiRates].
  final List<double> ifiLimits;
  final List<double> ifiRates;

  /// Patrimoine net en-dessous duquel l'IFI n'est pas dû du tout (voir
  /// `computeIFI`) — distinct du premier seuil de [ifiLimits] (à partir
  /// duquel le barème commence à taxer, une fois l'IFI dû).
  final double ifiSeuilImposition;

  /// Barème de l'usufruit (voir `nueProprietePct`/`computeDemembrement`).
  final List<UsufruitBracket> demembrementBrackets;

  /// Barème des droits de mutation à titre gratuit en ligne directe
  /// (parent/enfant, article 777 CGI — voir `directLineRights`).
  final List<TaxBracket> directLineBrackets;

  /// Barème des droits de donation entre époux/partenaires de PACS (voir
  /// `spouseRights`).
  final List<TaxBracket> spouseBrackets;

  /// Abattements par lien de parenté (voir `abattementFor`) — sert aussi de
  /// valeur de départ au champ "Abattement par enfant" des onglets
  /// Démembrement/Succession (`abattementEnfant`), avant toute saisie
  /// manuelle de l'utilisateur.
  final double abattementEnfant;
  final double abattementPetitEnfant;
  final double abattementConjoint;

  /// Part "impôt sur le revenu" du prélèvement forfaitaire unique ("flat
  /// tax", 12,8 % par défaut) — séparée de [pfuPsRate] (prélèvements
  /// sociaux) plutôt qu'un seul taux global de 30 %, puisque l'État peut
  /// réviser l'une sans l'autre (ex : PS passés de 15,5 % à 17,2 % en 2018,
  /// puis à 18,6 % début 2026, sans toucher au taux d'IR). Valeurs de
  /// référence pures : aucun calculateur de l'app ne les utilise pour
  /// l'instant (pas de simulateur de plus-value mobilière/revenus de
  /// capitaux), mais elles sont exposées dès maintenant dans les Réglages
  /// pour être prêtes le jour où un calcul en aura besoin.
  final double pfuIrRate;

  /// Part "prélèvements sociaux" du PFU (18,6 % par défaut depuis début
  /// 2026, contre 17,2 % auparavant) — voir [pfuIrRate].
  final double pfuPsRate;

  const TaxParameters({
    required this.irLimits,
    required this.irRates,
    required this.ifiLimits,
    required this.ifiRates,
    required this.ifiSeuilImposition,
    required this.demembrementBrackets,
    required this.directLineBrackets,
    required this.spouseBrackets,
    required this.abattementEnfant,
    required this.abattementPetitEnfant,
    required this.abattementConjoint,
    required this.pfuIrRate,
    required this.pfuPsRate,
  });

  /// Valeurs actuellement connues (barèmes 2024/2026, non révisés depuis) —
  /// ce que chaque calculateur utilisait en dur avant cette fonctionnalité,
  /// et vers quoi un bouton "Réinitialiser" ramène une valeur modifiée.
  ///
  /// Construit à partir des constantes top-level ci-dessous (`default...`)
  /// plutôt que de répéter les valeurs ici : ce sont ces mêmes constantes
  /// que les paramètres optionnels de `computeIR`/`computeIFI`/
  /// `nueProprietePct`/`abattementFor`/`directLineRights`/`spouseRights`
  /// utilisent comme valeur par défaut (accéder à un champ d'instance,
  /// même `const`, n'est pas une expression constante valide en Dart — d'où
  /// des identifiants top-level séparés plutôt que `defaults.irLimits` etc.
  /// utilisés directement comme valeur par défaut d'un paramètre).
  static const defaults = TaxParameters(
    irLimits: defaultIrLimits,
    irRates: defaultIrRates,
    ifiLimits: defaultIfiLimits,
    ifiRates: defaultIfiRates,
    ifiSeuilImposition: defaultIfiSeuilImposition,
    demembrementBrackets: defaultDemembrementBrackets,
    directLineBrackets: defaultDirectLineBrackets,
    spouseBrackets: defaultSpouseBrackets,
    abattementEnfant: defaultAbattementEnfant,
    abattementPetitEnfant: defaultAbattementPetitEnfant,
    abattementConjoint: defaultAbattementConjoint,
    pfuIrRate: defaultPfuIrRate,
    pfuPsRate: defaultPfuPsRate,
  );

  TaxParameters copyWith({
    List<double>? irLimits,
    List<double>? irRates,
    List<double>? ifiLimits,
    List<double>? ifiRates,
    double? ifiSeuilImposition,
    List<UsufruitBracket>? demembrementBrackets,
    List<TaxBracket>? directLineBrackets,
    List<TaxBracket>? spouseBrackets,
    double? abattementEnfant,
    double? abattementPetitEnfant,
    double? abattementConjoint,
    double? pfuIrRate,
    double? pfuPsRate,
  }) => TaxParameters(
    irLimits: irLimits ?? this.irLimits,
    irRates: irRates ?? this.irRates,
    ifiLimits: ifiLimits ?? this.ifiLimits,
    ifiRates: ifiRates ?? this.ifiRates,
    ifiSeuilImposition: ifiSeuilImposition ?? this.ifiSeuilImposition,
    demembrementBrackets: demembrementBrackets ?? this.demembrementBrackets,
    directLineBrackets: directLineBrackets ?? this.directLineBrackets,
    spouseBrackets: spouseBrackets ?? this.spouseBrackets,
    abattementEnfant: abattementEnfant ?? this.abattementEnfant,
    abattementPetitEnfant: abattementPetitEnfant ?? this.abattementPetitEnfant,
    abattementConjoint: abattementConjoint ?? this.abattementConjoint,
    pfuIrRate: pfuIrRate ?? this.pfuIrRate,
    pfuPsRate: pfuPsRate ?? this.pfuPsRate,
  );

  static List<double> _doubleList(dynamic value, List<double> fallback) {
    if (value is! List) return fallback;
    return [
      for (final v in value)
        if (v is num) v.toDouble(),
    ];
  }

  static List<TaxBracket> _bracketList(dynamic value, List<TaxBracket> fallback) {
    if (value is! List) return fallback;
    return [
      for (final v in value)
        if (v is Map<String, dynamic>) TaxBracket.fromJson(v),
    ];
  }

  factory TaxParameters.fromJson(Map<String, dynamic> json) {
    final d = TaxParameters.defaults;
    return TaxParameters(
      irLimits: _doubleList(json['irLimits'], d.irLimits),
      irRates: _doubleList(json['irRates'], d.irRates),
      ifiLimits: _doubleList(json['ifiLimits'], d.ifiLimits),
      ifiRates: _doubleList(json['ifiRates'], d.ifiRates),
      ifiSeuilImposition: (json['ifiSeuilImposition'] as num?)?.toDouble() ??
          d.ifiSeuilImposition,
      demembrementBrackets: json['demembrementBrackets'] is List
          ? [
              for (final v in json['demembrementBrackets'] as List)
                if (v is Map<String, dynamic>) UsufruitBracket.fromJson(v),
            ]
          : d.demembrementBrackets,
      directLineBrackets: _bracketList(
        json['directLineBrackets'],
        d.directLineBrackets,
      ),
      spouseBrackets: _bracketList(json['spouseBrackets'], d.spouseBrackets),
      abattementEnfant:
          (json['abattementEnfant'] as num?)?.toDouble() ?? d.abattementEnfant,
      abattementPetitEnfant:
          (json['abattementPetitEnfant'] as num?)?.toDouble() ??
          d.abattementPetitEnfant,
      abattementConjoint:
          (json['abattementConjoint'] as num?)?.toDouble() ??
          d.abattementConjoint,
      pfuIrRate: (json['pfuIrRate'] as num?)?.toDouble() ?? d.pfuIrRate,
      pfuPsRate: (json['pfuPsRate'] as num?)?.toDouble() ?? d.pfuPsRate,
    );
  }

  Map<String, dynamic> toJson() => {
    'irLimits': irLimits,
    'irRates': irRates,
    'ifiLimits': ifiLimits,
    'ifiRates': ifiRates,
    'ifiSeuilImposition': ifiSeuilImposition,
    'demembrementBrackets': [
      for (final b in demembrementBrackets) b.toJson(),
    ],
    'directLineBrackets': [for (final b in directLineBrackets) b.toJson()],
    'spouseBrackets': [for (final b in spouseBrackets) b.toJson()],
    'abattementEnfant': abattementEnfant,
    'abattementPetitEnfant': abattementPetitEnfant,
    'abattementConjoint': abattementConjoint,
    'pfuIrRate': pfuIrRate,
    'pfuPsRate': pfuPsRate,
  };
}
