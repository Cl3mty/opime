import 'dart:math';

enum LoanType { amortissable, inFine }

enum DeferType { totale, partielle }

class MonthEntry {
  final double capital;
  final double interest;
  final double insurance;
  MonthEntry({
    required this.capital,
    required this.interest,
    required this.insurance,
  });
}

class YearBar {
  final int year;
  final double capital;
  final double interest;
  final double insurance;
  YearBar({
    required this.year,
    required this.capital,
    required this.interest,
    required this.insurance,
  });
}

class LoanResult {
  final List<YearBar> years;
  final double mensualite;
  final double? mensualiteDifferee;
  final double assuranceMensuelle;
  final double coutTotalCredit;
  final double totalAssurance;
  final double coutTotalAvecFrais;
  final double montantEmprunte;
  final double? capitalRembourseInFine;

  /// Capital restant dû après le paiement de chaque mois (index 0 = fin du
  /// premier mois), du premier au dernier mois du prêt — sert à tracer la
  /// courbe de décroissance du capital restant dû (voir `features/liabilities/`)
  /// sans avoir à raisonner en années comme [years].
  final List<double> remainingBalanceByMonth;

  /// Détail mois par mois (capital/intérêts/assurance), avant agrégation en
  /// [years] — utilisé par `features/liabilities/` pour figer un tableau
  /// d'amortissement complet (avec dates) à la création/édition d'un
  /// passif réel, plutôt que de le re-dériver à chaque lecture.
  final List<MonthEntry> months;

  LoanResult({
    required this.years,
    required this.mensualite,
    required this.mensualiteDifferee,
    required this.assuranceMensuelle,
    required this.coutTotalCredit,
    required this.totalAssurance,
    required this.coutTotalAvecFrais,
    required this.montantEmprunte,
    required this.capitalRembourseInFine,
    required this.remainingBalanceByMonth,
    required this.months,
  });
}

/// Comme [simulateLoan], mais en "montant fixe + durée en mois" plutôt
/// qu'en "montant + durée en années" — les deux quantités réellement
/// nécessaires au calcul, [simulateLoan] ne faisant que la conversion
/// durée (années → mois), la mensualité d'assurance étant passée telle
/// quelle.
/// Utilisée directement par `features/liabilities/` (formulaire de crédit
/// réel, dont les champs sont "assurance mensuelle (€)" et "nombre
/// d'échéances (mois)"), où [totalMonths] n'est pas forcément un multiple
/// de 12.
///
/// - In fine : intérêts constants sur le capital initial chaque mois,
///   capital remboursé en une fois au dernier mois.
/// - Amortissable : mensualité constante calculée par la formule standard
///   `M = C·i / (1 - (1+i)^-n)`, avec un différé optionnel où le capital
///   restant dû n'est pas encore amorti (franchise partielle : seuls les
///   intérêts sont payés ; franchise totale : les intérêts s'ajoutent au
///   capital restant dû, rien n'est décaissé).
LoanResult simulateLoanByMonths({
  required double montantEmprunte,
  required int totalMonths,
  required double tauxInteret,
  required double assuranceMensuelle,
  required double fraisDossier,
  required double fraisGarantie,
  required LoanType type,
  required bool differeActif,
  required int dureeDiffereMois,
  required DeferType typeDiffere,
}) {
  final i = tauxInteret / 100 / 12;
  final insuranceMonthly = assuranceMensuelle;
  final months = <MonthEntry>[];
  final remainingBalanceByMonth = <double>[];

  if (type == LoanType.inFine) {
    for (var m = 1; m <= totalMonths; m++) {
      final interest = montantEmprunte * i;
      final capital = (m == totalMonths) ? montantEmprunte : 0.0;
      months.add(
        MonthEntry(
          capital: capital,
          interest: interest,
          insurance: insuranceMonthly,
        ),
      );
      remainingBalanceByMonth.add(m == totalMonths ? 0.0 : montantEmprunte);
    }
  } else {
    var remaining = montantEmprunte;
    final deferMonths = differeActif
        ? dureeDiffereMois.clamp(0, totalMonths - 1)
        : 0;

    for (var m = 1; m <= deferMonths; m++) {
      final interest = remaining * i;
      if (typeDiffere == DeferType.totale) {
        remaining += interest; // intérêts capitalisés, rien n'est décaissé
      }
      months.add(
        MonthEntry(capital: 0, interest: interest, insurance: insuranceMonthly),
      );
      remainingBalanceByMonth.add(remaining);
    }

    final remainingMonths = totalMonths - deferMonths;
    if (remainingMonths > 0) {
      final monthlyPayment = i == 0
          ? remaining / remainingMonths
          : remaining * i / (1 - pow(1 + i, -remainingMonths));
      for (var m = 1; m <= remainingMonths; m++) {
        final interest = remaining * i;
        final capital = monthlyPayment - interest;
        remaining -= capital;
        months.add(
          MonthEntry(
            capital: capital,
            interest: interest,
            insurance: insuranceMonthly,
          ),
        );
        remainingBalanceByMonth.add(max(0.0, remaining));
      }
    }
  }

  // Agrégation par année (moyenne mensuelle de l'année, pour le graphique) —
  // la dernière tranche peut compter moins de 12 mois si totalMonths n'est
  // pas un multiple de 12.
  final years = <YearBar>[];
  for (var y = 0; y * 12 < totalMonths; y++) {
    final slice = months.skip(y * 12).take(12).toList();
    if (slice.isEmpty) continue;
    final capital =
        slice.map((m) => m.capital).reduce((a, b) => a + b) / slice.length;
    final interest =
        slice.map((m) => m.interest).reduce((a, b) => a + b) / slice.length;
    final insurance =
        slice.map((m) => m.insurance).reduce((a, b) => a + b) / slice.length;
    years.add(
      YearBar(
        year: y,
        capital: capital,
        interest: interest,
        insurance: insurance,
      ),
    );
  }

  final totalInterest = months.fold<double>(0, (s, m) => s + m.interest);
  final totalInsurance = months.fold<double>(0, (s, m) => s + m.insurance);
  final coutTotalCredit = totalInterest + totalInsurance;
  final coutTotalAvecFrais = coutTotalCredit + fraisDossier + fraisGarantie;

  final deferMonths = (type == LoanType.amortissable && differeActif)
      ? dureeDiffereMois.clamp(0, totalMonths - 1)
      : 0;
  // Pour un amortissable classique, la mensualité est constante hors dernier mois d'arrondi :
  // on prend plutôt le paiement du premier mois de la phase d'amortissement.
  final mensualiteAffichee = type == LoanType.inFine
      ? montantEmprunte * i + insuranceMonthly
      : (deferMonths < months.length
            ? (months[deferMonths].capital +
                  months[deferMonths].interest +
                  months[deferMonths].insurance)
            : 0.0);

  // En franchise totale, les intérêts du différé sont capitalisés (ajoutés au
  // capital restant dû) et non décaissés : seule l'assurance est réellement
  // payée chaque mois. En franchise partielle, les intérêts sont, eux, payés.
  final mensualiteDifferee = deferMonths > 0
      ? (typeDiffere == DeferType.totale
            ? insuranceMonthly
            : months[0].capital + months[0].interest + months[0].insurance)
      : null;

  return LoanResult(
    years: years,
    mensualite: mensualiteAffichee,
    mensualiteDifferee: mensualiteDifferee,
    assuranceMensuelle: insuranceMonthly,
    coutTotalCredit: coutTotalCredit,
    totalAssurance: totalInsurance,
    coutTotalAvecFrais: coutTotalAvecFrais,
    montantEmprunte: montantEmprunte,
    capitalRembourseInFine: type == LoanType.inFine ? montantEmprunte : null,
    remainingBalanceByMonth: remainingBalanceByMonth,
    months: months,
  );
}

/// Point d'entrée du simulateur (`simulations/simulations_loan_screen.dart`),
/// dont les champs sont une assurance mensuelle (€) et une durée en années —
/// convertis ici vers les unités attendues par [simulateLoanByMonths], qui
/// porte tout le calcul.
LoanResult simulateLoan({
  required double montantEmprunte,
  required int dureeAnnees,
  required double tauxInteret,
  required double assuranceMensuelle,
  required double fraisDossier,
  required double fraisGarantie,
  required LoanType type,
  required bool differeActif,
  required int dureeDiffereMois,
  required DeferType typeDiffere,
}) => simulateLoanByMonths(
  montantEmprunte: montantEmprunte,
  totalMonths: dureeAnnees * 12,
  tauxInteret: tauxInteret,
  assuranceMensuelle: assuranceMensuelle,
  fraisDossier: fraisDossier,
  fraisGarantie: fraisGarantie,
  type: type,
  differeActif: differeActif,
  dureeDiffereMois: dureeDiffereMois,
  typeDiffere: typeDiffere,
);
