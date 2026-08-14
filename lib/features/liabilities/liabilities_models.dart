import '../../core/money_format.dart' show round2;
import '../investments/investments_models.dart'
    show generateInvestmentId, VaultDocument;
import '../simulations/loan_calculator.dart';

/// Type de passif — mêmes deux catégories que le Dashboard de démo
/// (`patrimoine_models.dart`, ids `passifs_prets_immobiliers` /
/// `passifs_emprunts`), pour que les passifs réels remplacent directement
/// les données d'exemple dans les mêmes cartes.
enum LiabilityType {
  pretImmobilier,
  creditAutre;

  String get label => switch (this) {
    LiabilityType.pretImmobilier => 'Prêt immobilier',
    LiabilityType.creditAutre => 'Crédit autre',
  };

  String get categoryId => switch (this) {
    LiabilityType.pretImmobilier => 'passifs_prets_immobiliers',
    LiabilityType.creditAutre => 'passifs_emprunts',
  };

  static LiabilityType fromName(String name) => LiabilityType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => LiabilityType.creditAutre,
  );
}

/// Retrouve le [LiabilityType] correspondant à un id de catégorie Dashboard
/// (`'passifs_emprunts'`...), ou `null` si l'id ne correspond à aucun passif
/// réel (ex : ids `actifs_*`).
LiabilityType? liabilityTypeForCategoryId(String categoryId) {
  for (final type in LiabilityType.values) {
    if (type.categoryId == categoryId) return type;
  }
  return null;
}

String formatFrenchDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

DateTime _parseFrenchDate(String text) {
  final parts = text.split('/');
  return DateTime(
    int.parse(parts[2]),
    int.parse(parts[1]),
    int.parse(parts[0]),
  );
}

/// Une ligne du tableau d'amortissement d'un [Liability] : calculé une
/// seule fois (à la création, ou à chaque édition des paramètres du prêt —
/// voir [Liability]'s constructeur) puis persisté tel quel, plutôt que
/// re-dérivé à chaque lecture comme le fait encore le simulateur
/// (`features/simulations/loan_calculator.dart`).
class AmortissementEntry {
  final DateTime date;
  final int mois;
  final double mensualite;
  final double interet;
  final double remboursementPrincipal;
  final double assurance;
  final double capitalRestantDu;

  const AmortissementEntry({
    required this.date,
    required this.mois,
    required this.mensualite,
    required this.interet,
    required this.remboursementPrincipal,
    required this.assurance,
    required this.capitalRestantDu,
  });

  factory AmortissementEntry.fromJson(Map<String, dynamic> json) =>
      AmortissementEntry(
        date: _parseFrenchDate(json['date'] as String),
        mois: json['mois'] as int? ?? 0,
        mensualite: (json['mensualite'] as num?)?.toDouble() ?? 0,
        interet: (json['interet'] as num?)?.toDouble() ?? 0,
        remboursementPrincipal:
            (json['remboursementPrincipal'] as num?)?.toDouble() ?? 0,
        assurance: (json['assurance'] as num?)?.toDouble() ?? 0,
        capitalRestantDu: (json['capitalRestantDu'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'date': formatFrenchDate(date),
    'mois': mois,
    'mensualite': round2(mensualite),
    'interet': round2(interet),
    'remboursementPrincipal': round2(remboursementPrincipal),
    'assurance': round2(assurance),
    'capitalRestantDu': round2(capitalRestantDu),
  };
}

/// Un prêt réel. Son tableau d'amortissement complet ([amortissement]) est
/// calculé une fois à partir des paramètres saisis (via
/// [simulateLoanByMonths]) puis figé/persisté tel quel — pas re-dérivé à
/// chaque lecture comme avant. Modifier un paramètre qui influence le
/// calcul (montant, taux, échéances...) via [copyWith] régénère
/// automatiquement un nouveau tableau ; modifier seulement les documents
/// conserve le tableau existant.
///
/// [nbrEcheances] et [assuranceMensuelle] sont saisis directement par
/// l'utilisateur (nombre de mensualités hors différé, montant mensuel de
/// l'assurance) plutôt qu'une durée en années ou un taux d'assurance en %
/// — au contraire du simulateur (`simulations/loan_calculator.dart`), qui
/// garde ces derniers pour son propre formulaire.
class Liability {
  final String id;
  final LiabilityType type;
  final String name;

  /// Capital effectivement emprunté, déjà net de l'apport (`prix - apport`
  /// — calculé par l'appelant avant construction, voir les formulaires de
  /// création/édition).
  final double montantEmprunte;
  final double apport;
  final double tauxInteret;
  final double assuranceMensuelle;
  final double fraisDossier;
  final double fraisGarantie;

  /// Nombre de mensualités amortissantes, hors différé (voir
  /// [dureeDiffereMois]) — la durée totale du prêt est donc
  /// `nbrEcheances + dureeDiffereMois` mois.
  final int nbrEcheances;
  final DateTime dateDebut;
  final LoanType loanType;
  final bool differeActif;
  final int dureeDiffereMois;
  final DeferType typeDiffere;
  final List<AmortissementEntry> amortissement;
  final List<VaultDocument> documents;

  Liability({
    String? id,
    required this.type,
    required this.name,
    required this.montantEmprunte,
    this.apport = 0,
    required this.tauxInteret,
    this.assuranceMensuelle = 0,
    this.fraisDossier = 0,
    this.fraisGarantie = 0,
    required this.nbrEcheances,
    required this.dateDebut,
    this.loanType = LoanType.amortissable,
    this.differeActif = false,
    this.dureeDiffereMois = 0,
    this.typeDiffere = DeferType.partielle,
    List<AmortissementEntry>? amortissement,
    this.documents = const [],
  }) : id = id ?? generateInvestmentId('liab'),
       amortissement =
           amortissement ??
           _buildAmortissement(
             montantEmprunte: montantEmprunte,
             nbrEcheances: nbrEcheances,
             tauxInteret: tauxInteret,
             assuranceMensuelle: assuranceMensuelle,
             fraisDossier: fraisDossier,
             fraisGarantie: fraisGarantie,
             loanType: loanType,
             differeActif: differeActif,
             dureeDiffereMois: dureeDiffereMois,
             typeDiffere: typeDiffere,
             dateDebut: dateDebut,
           );

  static List<AmortissementEntry> _buildAmortissement({
    required double montantEmprunte,
    required int nbrEcheances,
    required double tauxInteret,
    required double assuranceMensuelle,
    required double fraisDossier,
    required double fraisGarantie,
    required LoanType loanType,
    required bool differeActif,
    required int dureeDiffereMois,
    required DeferType typeDiffere,
    required DateTime dateDebut,
  }) {
    final result = simulateLoanByMonths(
      montantEmprunte: montantEmprunte,
      totalMonths: nbrEcheances + dureeDiffereMois,
      tauxInteret: tauxInteret,
      assuranceMensuelle: assuranceMensuelle,
      fraisDossier: fraisDossier,
      fraisGarantie: fraisGarantie,
      type: loanType,
      differeActif: differeActif,
      dureeDiffereMois: dureeDiffereMois,
      typeDiffere: typeDiffere,
    );
    return [
      for (var i = 0; i < result.months.length; i++)
        AmortissementEntry(
          date: DateTime(dateDebut.year, dateDebut.month + i, dateDebut.day),
          mois: i + 1,
          mensualite:
              result.months[i].capital +
              result.months[i].interest +
              result.months[i].insurance,
          interet: result.months[i].interest,
          remboursementPrincipal: result.months[i].capital,
          assurance: result.months[i].insurance,
          capitalRestantDu: result.remainingBalanceByMonth[i],
        ),
    ];
  }

  /// Régénère [amortissement] seulement si un paramètre qui influence le
  /// calcul change (voir [_buildAmortissement]) — un ajout/suppression de
  /// document, lui, conserve le tableau déjà figé.
  Liability copyWith({
    String? name,
    double? montantEmprunte,
    double? apport,
    double? tauxInteret,
    double? assuranceMensuelle,
    double? fraisDossier,
    double? fraisGarantie,
    int? nbrEcheances,
    DateTime? dateDebut,
    LoanType? loanType,
    bool? differeActif,
    int? dureeDiffereMois,
    DeferType? typeDiffere,
    List<VaultDocument>? documents,
  }) {
    final scheduleChanged =
        montantEmprunte != null ||
        tauxInteret != null ||
        assuranceMensuelle != null ||
        fraisDossier != null ||
        fraisGarantie != null ||
        nbrEcheances != null ||
        dateDebut != null ||
        loanType != null ||
        differeActif != null ||
        dureeDiffereMois != null ||
        typeDiffere != null;
    return Liability(
      id: id,
      type: type,
      name: name ?? this.name,
      montantEmprunte: montantEmprunte ?? this.montantEmprunte,
      apport: apport ?? this.apport,
      tauxInteret: tauxInteret ?? this.tauxInteret,
      assuranceMensuelle: assuranceMensuelle ?? this.assuranceMensuelle,
      fraisDossier: fraisDossier ?? this.fraisDossier,
      fraisGarantie: fraisGarantie ?? this.fraisGarantie,
      nbrEcheances: nbrEcheances ?? this.nbrEcheances,
      dateDebut: dateDebut ?? this.dateDebut,
      loanType: loanType ?? this.loanType,
      differeActif: differeActif ?? this.differeActif,
      dureeDiffereMois: dureeDiffereMois ?? this.dureeDiffereMois,
      typeDiffere: typeDiffere ?? this.typeDiffere,
      amortissement: scheduleChanged ? null : amortissement,
      documents: documents ?? this.documents,
    );
  }

  int get _totalMonths => amortissement.length;

  /// Nombre de mois écoulés depuis [dateDebut], borné à la durée totale du
  /// prêt (jamais négatif avant le début, jamais au-delà de l'échéance).
  int get monthsElapsed {
    final now = DateTime.now();
    final months =
        (now.year - dateDebut.year) * 12 + (now.month - dateDebut.month);
    return months.clamp(0, _totalMonths);
  }

  bool get isPaidOff => _totalMonths > 0 && monthsElapsed >= _totalMonths;

  /// Capital restant dû aujourd'hui, lu dans [amortissement] — 0 une fois
  /// le prêt totalement remboursé.
  double get remainingBalance {
    if (amortissement.isEmpty) return 0;
    if (monthsElapsed == 0) return montantEmprunte;
    final index = (monthsElapsed - 1).clamp(0, amortissement.length - 1);
    return amortissement[index].capitalRestantDu;
  }

  /// Capital restant dû après le paiement de chaque mois — même usage que
  /// l'ancien `LoanResult.remainingBalanceByMonth`, désormais lu depuis le
  /// tableau figé plutôt que re-simulé.
  List<double> get remainingBalanceByMonth => [
    for (final entry in amortissement) entry.capitalRestantDu,
  ];

  /// Mensualité (hors phase de différé), pour l'affichage — le premier mois
  /// de la phase d'amortissement réelle (index [dureeDiffereMois]), ou le
  /// tout premier mois pour un prêt in fine (pas de différé applicable).
  double get mensualite {
    if (amortissement.isEmpty) return 0;
    final index = loanType == LoanType.inFine
        ? 0
        : dureeDiffereMois.clamp(0, amortissement.length - 1);
    return amortissement[index].mensualite;
  }

  /// Agrégation annuelle (moyenne mensuelle de l'année) de [amortissement]
  /// — même forme que l'ancien `LoanResult.years`, pour le graphique en
  /// barres empilées (`features/simulations/loan_chart.dart`). La dernière
  /// tranche peut compter moins de 12 mois si la durée totale n'est pas un
  /// multiple de 12.
  List<YearBar> get years {
    final result = <YearBar>[];
    for (var y = 0; y * 12 < amortissement.length; y++) {
      final slice = amortissement.skip(y * 12).take(12).toList();
      if (slice.isEmpty) continue;
      result.add(
        YearBar(
          year: y,
          capital:
              slice
                  .map((m) => m.remboursementPrincipal)
                  .reduce((a, b) => a + b) /
              slice.length,
          interest:
              slice.map((m) => m.interet).reduce((a, b) => a + b) /
              slice.length,
          insurance:
              slice.map((m) => m.assurance).reduce((a, b) => a + b) /
              slice.length,
        ),
      );
    }
    return result;
  }

  factory Liability.fromJson(Map<String, dynamic> json) {
    final nbrEcheancesDifferees = json['nbrEcheancesDifferees'] as int? ?? 0;
    final amortissementJson = json['amortissement'] as List? ?? [];
    return Liability(
      id: json['id'] as String? ?? generateInvestmentId('liab'),
      type: LiabilityType.fromName(json['type'] as String? ?? ''),
      name: json['nom'] as String? ?? '',
      montantEmprunte: (json['capital'] as num?)?.toDouble() ?? 0,
      apport: (json['apport'] as num?)?.toDouble() ?? 0,
      tauxInteret: (json['TAEG'] as num?)?.toDouble() ?? 0,
      assuranceMensuelle: (json['assuranceMensuelle'] as num?)?.toDouble() ?? 0,
      fraisDossier: (json['fraisDossier'] as num?)?.toDouble() ?? 0,
      fraisGarantie: (json['fraisGarantie'] as num?)?.toDouble() ?? 0,
      nbrEcheances: json['nbrEcheances'] as int? ?? 0,
      dateDebut: _parseFrenchDate(json['dateEmprunt'] as String),
      loanType: (json['loanType'] as String?) == 'inFine'
          ? LoanType.inFine
          : LoanType.amortissable,
      differeActif: nbrEcheancesDifferees > 0,
      dureeDiffereMois: nbrEcheancesDifferees,
      typeDiffere: (json['typeDiffere'] as String?) == 'totale'
          ? DeferType.totale
          : DeferType.partielle,
      amortissement: amortissementJson
          .map((e) => AmortissementEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: (json['documents'] as List? ?? [])
          .map((e) => VaultDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'nom': name,
    'capital': round2(montantEmprunte),
    'apport': round2(apport),
    'TAEG': round2(tauxInteret),
    'nbrEcheances': nbrEcheances,
    'assuranceMensuelle': round2(assuranceMensuelle),
    'fraisDossier': round2(fraisDossier),
    'nbrEcheancesDifferees': dureeDiffereMois,
    'dateEmprunt': formatFrenchDate(dateDebut),
    'amortissement': amortissement.map((e) => e.toJson()).toList(),
    'loanType': loanType.name,
    'typeDiffere': typeDiffere.name,
    'fraisGarantie': round2(fraisGarantie),
    if (documents.isNotEmpty)
      'documents': documents.map((d) => d.toJson()).toList(),
  };
}
