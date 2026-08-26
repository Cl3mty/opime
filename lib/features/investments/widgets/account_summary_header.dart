import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/date_format.dart';
import '../../../core/money_format.dart';
import '../investments_models.dart';
import '../performance_calculator.dart';
import 'fiscal_milestone_bar.dart';
import 'peg_pee_unlock_card.dart';
import 'transaction_widgets.dart' show ExcludedFromPatrimoineBadge;

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Résumé d'un compte en mode affichage (hors édition) : type de compte,
/// date d'ouverture, jalon fiscal (PEA/assurance vie) ou échéancier de
/// déblocage (PEG/PEE), montant total et rendement pondéré par les apports
/// (MWR) sur la période complète. Partagé par la page compte générique
/// (`account_detail_screen.dart`'s `AccountDetailView`, toutes classes
/// d'actif hors Actions & Fonds) et l'écran compte dédié Actions & Fonds
/// (`stock_account/stock_account_screen.dart`) : même en-tête, seul le
/// corps de page diffère entre les deux.
class AccountSummaryHeader extends StatelessWidget {
  final InvestmentAccount account;
  final bool hidden;

  const AccountSummaryHeader({
    super.key,
    required this.account,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final pricedInvestments = account.investments
        .where((i) => i.marketValue != null)
        .toList();
    final mwr = pricedInvestments.isEmpty
        ? null
        : calculateMwr(
            transactions: [
              for (final i in pricedInvestments) ...i.transactions,
            ],
            currentValue: pricedInvestments.fold(
              0.0,
              (sum, i) => sum + i.marketValue!,
            ),
            asOf: DateTime.now(),
          );
    final fiscalMilestone = accountFiscalMilestone(
      envelope: account.envelope,
      openingDate: account.openingDate,
    );
    // PEG/PEE : contrairement au PEA/à l'assurance vie, le déblocage n'est
    // pas un jalon unique sur le compte entier — chaque versement se
    // débloque séparément 5 ans après sa propre date (voir
    // `pegPeeUnlockTranches`).
    final pegPeeTranches =
        account.envelope == AccountEnvelope.peg ||
            account.envelope == AccountEnvelope.pee
        ? pegPeeUnlockTranches(investments: account.investments)
        : const <UnlockTranche>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        shadcn.Text(_subtitle).muted().small(),
        if (account.excludedFromPatrimoine) ...[
          const SizedBox(height: 2),
          const ExcludedFromPatrimoineBadge(),
        ],
        if (account.openingDate != null) ...[
          const SizedBox(height: 2),
          shadcn.Text(
            'Ouvert le ${formatDateDdMmYyyy(account.openingDate!)}',
          ).muted().xSmall(),
        ],
        if (fiscalMilestone != null) ...[
          const SizedBox(height: 2),
          shadcn.Text(
            _fiscalMilestoneLabel(fiscalMilestone),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: fiscalMilestone.reached
                  ? _green
                  : Theme.of(context).colorScheme.mutedForeground,
            ),
          ).xSmall(),
          if (!fiscalMilestone.reached) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 220,
              child: FiscalMilestoneBar(
                openingDate: account.openingDate!,
                milestone: fiscalMilestone,
              ),
            ),
          ],
        ],
        if (pegPeeTranches.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: 260,
            child: PegPeeUnlockCard(tranches: pegPeeTranches),
          ),
        ],
        const SizedBox(height: 4),
        shadcn.Text(
          displayEuros(account.totalMarketValue, hidden),
        ).x2Large().bold(),
        const SizedBox(height: 2),
        shadcn.Text(
          pricedInvestments.length == account.investments.length &&
                  account.investments.isNotEmpty
              ? 'Valorisation au dernier cours connu'
              : 'Montant net investi (cours pas encore disponible pour '
                    'tous les investissements)',
        ).muted().xSmall(),
        if (mwr != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mwr.rate >= 0
                    ? LucideIcons.trendingUp
                    : LucideIcons.trendingDown,
                size: 14,
                color: mwr.rate >= 0 ? _green : _red,
              ),
              const SizedBox(width: 4),
              shadcn.Text(
                mwr.annualized
                    ? '${displayPercent(mwr.rate * 100)} par an (MWR, '
                          'rendement pondéré par vos apports)'
                    : '${displayPercent(mwr.rate * 100)} depuis le début '
                          '(MWR, moins d\'un an de recul)',
                style: TextStyle(
                  color: mwr.rate >= 0 ? _green : _red,
                  fontWeight: FontWeight.w600,
                ),
              ).xSmall(),
            ],
          ),
        ],
      ],
    );
  }

  /// Type de compte affiché sous le titre (déjà [account.name]) — pour une
  /// enveloppe avec établissement (PEA, CTO, assurance vie...), le nom EST
  /// déjà le libellé de l'enveloppe (voir `_commitEditAccountName` dans
  /// `account_detail_screen.dart`/`stock_account_screen.dart`) : le
  /// répéter ici ("Actions & Fonds · PEA" sous un titre "PEA") n'apporte
  /// rien, alors que l'établissement (la banque) ne s'affiche nulle part
  /// ailleurs. Dans ce cas, on montre l'établissement à la place — sinon
  /// (épargne, crypto, métaux physiques...) le nom et l'enveloppe diffèrent
  /// déjà, pas de changement.
  String get _subtitle {
    final envelope = account.envelope;
    if (envelope == null) return account.assetClass.label;
    // Un type "Autres" personnalisé (voir
    // `InvestmentAccount.customOtherCategory`) tient lieu de libellé
    // d'enveloppe pour cette comparaison, exactement comme le libellé
    // générique de l'enveloppe pour les autres classes.
    final envelopeDisplay = account.customOtherCategory ?? envelope.label;
    final nameIsEnvelopeLabel = account.name == envelopeDisplay;
    final bankName = account.bankName;
    if (nameIsEnvelopeLabel) {
      return bankName == null
          ? account.assetClass.label
          : '${account.assetClass.label} · $bankName';
    }
    return '${account.assetClass.label} · $envelopeDisplay';
  }

  /// Texte du jalon fiscal — voir [accountFiscalMilestone] pour le calcul
  /// et le détail des règles (5 ans PEA, 8 ans assurance vie). Ne concerne
  /// pas PEG/PEE, dont le déblocage se calcule par versement — voir
  /// [PegPeeUnlockCard].
  String _fiscalMilestoneLabel(FiscalMilestone milestone) {
    final date = formatDateDdMmYyyy(milestone.date);
    if (milestone.reached) return 'Avantage fiscal actif depuis le $date';

    final days = milestone.date.difference(DateTime.now()).inDays;
    final delay = days < 31
        ? '$days jour${days > 1 ? 's' : ''}'
        : days < 365
        ? '${(days / 30).round()} mois'
        : '${(days / 365).round()} ans';
    return 'Avantage fiscal le $date (dans $delay)';
  }
}
