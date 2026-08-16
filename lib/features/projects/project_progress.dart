import '../investments/investments_models.dart' show InvestmentAccount;
import '../liabilities/liabilities_models.dart' show Liability;
import 'project_models.dart';

/// Résultat de [computeProjectProgress] : [percent] est `null` si le projet
/// n'a pas de montant cible (l'avancement se limite alors au temps restant,
/// toujours renseigné dans [timeRemaining] — négatif si [Project.echeance]
/// est dépassée).
typedef ProjectProgress = ({
  double? percent,
  double currentNetValue,
  Duration timeRemaining,
});

/// Calcule l'avancement d'un projet : valeur nette actuelle des actifs et
/// passifs qui lui sont rattachés (actifs − passifs), rapportée au montant
/// cible s'il y en a un, et temps restant jusqu'à l'échéance.
///
/// Un lien qui ne se résout plus (l'investissement ou le passif visé a été
/// supprimé ailleurs depuis) est ignoré silencieusement — contribution
/// nulle, jamais d'exception : c'est le premier endroit du code où une
/// fonctionnalité référence par id des entités appartenant à d'autres
/// repositories, sans qu'aucun mécanisme de purge automatique n'existe
/// entre elles.
ProjectProgress computeProjectProgress({
  required Project project,
  required List<InvestmentAccount> accounts,
  required List<Liability> liabilities,
  required DateTime today,
}) {
  var assetsValue = 0.0;
  for (final link in project.assetLinks) {
    for (final account in accounts) {
      if (account.id != link.accountId) continue;
      for (final investment in account.investments) {
        if (investment.id == link.investmentId) {
          assetsValue += investment.effectiveMarketValue ?? investment.investedAmount;
        }
      }
    }
  }

  var liabilitiesValue = 0.0;
  for (final link in project.liabilityLinks) {
    for (final liability in liabilities) {
      if (liability.id == link.liabilityId) {
        liabilitiesValue += liability.remainingBalance;
      }
    }
  }

  final netValue = assetsValue - liabilitiesValue;
  final target = project.montantCible;
  final percent = (target == null || target == 0) ? null : netValue / target * 100;

  return (
    percent: percent,
    currentNetValue: netValue,
    timeRemaining: project.echeance.difference(today),
  );
}

/// `true` si au moins un lien de [project] ne se résout plus dans [accounts]
/// / [liabilities] — utilisé par l'éditeur pour signaler discrètement un
/// lien mort (élément supprimé ailleurs depuis), sans bloquer l'affichage.
bool hasDanglingLinks({
  required Project project,
  required List<InvestmentAccount> accounts,
  required List<Liability> liabilities,
}) {
  for (final link in project.assetLinks) {
    final account = accounts.where((a) => a.id == link.accountId).firstOrNull;
    if (account == null) return true;
    final found = account.investments.any((i) => i.id == link.investmentId);
    if (!found) return true;
  }
  for (final link in project.liabilityLinks) {
    final found = liabilities.any((l) => l.id == link.liabilityId);
    if (!found) return true;
  }
  return false;
}
