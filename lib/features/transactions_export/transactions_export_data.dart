/// Couche de données pure de l'export des transactions : aplatit
/// `Investment.transactions` de tous les comptes en lignes autonomes, sans
/// dépendance à Flutter ni au format de sortie (JSON/CSV) — testable en
/// isolation, voir `transactions_export_json.dart`/`transactions_export_csv
/// .dart` pour la mise en forme réelle.
library;

import '../investments/investments_models.dart';

/// Une transaction aplatie avec son contexte (compte/investissement) — une
/// ligne autonome d'export, lisible sans avoir à recroiser d'autres lignes.
///
/// [linkedContext] résout la contrepartie d'un transfert/arbitrage (voir
/// [Transaction.linkedTransactionId]) en un texte lisible ("Vers CTO Bourso
/// · Apple") plutôt que de n'exposer qu'un id technique — la contrepartie
/// peut vivre dans un compte différent de celui de cette ligne (transfert),
/// voire dans un compte non sélectionné pour l'export : la résolution se
/// fait sur l'ensemble du vault, indépendamment de la sélection courante
/// (voir [buildTransactionExportRows]).
class TransactionExportRow {
  final String id;
  final DateTime date;
  final String accountName;
  final String investmentLabel;
  final bool isBuy;
  final double quantity;
  final double unitPrice;
  final String currency;
  final double fxRateToEur;

  /// Montant en euros — voir [Transaction.amount].
  final double amountEur;

  /// Libellé du type de mouvement (voir [TransactionType.label]), `null`
  /// pour un achat/vente classique.
  final String? type;
  final String? note;
  final String? linkedContext;

  const TransactionExportRow({
    required this.id,
    required this.date,
    required this.accountName,
    required this.investmentLabel,
    required this.isBuy,
    required this.quantity,
    required this.unitPrice,
    required this.currency,
    required this.fxRateToEur,
    required this.amountEur,
    this.type,
    this.note,
    this.linkedContext,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'compte': accountName,
    'investissement': investmentLabel,
    'sens': isBuy ? 'achat' : 'vente',
    'quantite': quantity,
    'prixUnitaire': unitPrice,
    'devise': currency,
    'tauxDeChange': fxRateToEur,
    'montantEur': amountEur,
    if (type != null) 'type': type,
    if (note != null) 'note': note,
    if (linkedContext != null) 'lien': linkedContext,
  };
}

/// Index id de transaction -> (nom du compte, libellé de l'investissement)
/// porteur, construit sur TOUS les comptes du vault (pas seulement ceux
/// sélectionnés pour l'export) — même principe de parcours complet que
/// `InvestmentsRepository.deleteTransaction`, en lecture seule ici : la
/// contrepartie d'un transfert peut se trouver dans un compte différent de
/// celui affiché, voire non retenu pour cet export.
Map<String, (String accountName, String investmentLabel)>
_buildTransactionLocationIndex(List<InvestmentAccount> accounts) {
  final index = <String, (String, String)>{};
  for (final account in accounts) {
    for (final investment in account.investments) {
      for (final transaction in investment.transactions) {
        index[transaction.id] = (account.name, investment.label);
      }
    }
  }
  return index;
}

/// Construit les lignes d'export pour les comptes dont l'id figure dans
/// [selectedAccountIds] — [allAccounts] doit rester la liste COMPLÈTE du
/// vault (utilisée pour résoudre le contexte des contreparties de
/// transfert, voir la doc de [TransactionExportRow.linkedContext]), même si
/// seule une partie est effectivement exportée. Trié par date croissante.
List<TransactionExportRow> buildTransactionExportRows(
  List<InvestmentAccount> allAccounts, {
  required Set<String> selectedAccountIds,
}) {
  final locationById = _buildTransactionLocationIndex(allAccounts);
  final rows = <TransactionExportRow>[];
  for (final account in allAccounts) {
    if (!selectedAccountIds.contains(account.id)) continue;
    for (final investment in account.investments) {
      for (final transaction in investment.transactions) {
        String? linkedContext;
        final linkedId = transaction.linkedTransactionId;
        if (linkedId != null) {
          final location = locationById[linkedId];
          if (location != null) {
            final direction = transaction.isBuy ? 'Depuis' : 'Vers';
            linkedContext = '$direction ${location.$1} · ${location.$2}';
          }
        }
        rows.add(
          TransactionExportRow(
            id: transaction.id,
            date: transaction.date,
            accountName: account.name,
            investmentLabel: investment.label,
            isBuy: transaction.isBuy,
            quantity: transaction.quantity,
            unitPrice: transaction.unitPrice,
            currency: transaction.currency,
            fxRateToEur: transaction.fxRateToEur,
            amountEur: transaction.amount,
            type: transaction.type?.label,
            note: transaction.note,
            linkedContext: linkedContext,
          ),
        );
      }
    }
  }
  rows.sort((a, b) => a.date.compareTo(b.date));
  return rows;
}
