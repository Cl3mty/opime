import '../budget/budget_tracking_repository.dart';
import '../investments/investments_models.dart' show InvestmentAccount;
import '../investments/investments_repository.dart';
import '../investments/price_history_repository.dart';
import '../investments/real_patrimoine_adapter.dart'
    show earliestTransactionDateAcrossAccounts, loadAllPriceHistories;
import '../investments/yahoo_finance_client.dart' show PricePoint;
import '../liabilities/liabilities_models.dart' show Liability;
import '../liabilities/liabilities_repository.dart';
import 'analyses_settings_repository.dart';

/// Préfixe distinguant la clé de cache du benchmark d'un vrai ISIN — voir
/// [PriceHistoryRepository], réutilisé tel quel pour l'historique du
/// benchmark plutôt que de dupliquer la logique HTTP/interpolation/cache.
const benchmarkCacheKeyPrefix = 'BENCHMARK_';

/// Photo d'ensemble des données nécessaires à l'écran Analyses, assemblée en
/// une passe pour garder `analyses_screen.dart` libre de toute logique
/// d'E/S — même rôle que `real_patrimoine_adapter.dart` pour le Dashboard.
class AnalysesSnapshot {
  final List<InvestmentAccount> accounts;
  final List<Liability> liabilities;
  final Map<String, List<PricePoint>> priceHistories;
  final String? benchmarkTicker;
  final List<PricePoint> benchmarkHistory;

  /// Revenus réels du mois en cours, saisis dans Budget > Suivi — `null` si
  /// aucun n'est renseigné (`totalRevenuesRealite == 0`) : le taux
  /// d'endettement basé sur les revenus reste alors non calculable plutôt
  /// que de diviser par un revenu nul.
  final double? monthlyIncome;

  const AnalysesSnapshot({
    required this.accounts,
    required this.liabilities,
    required this.priceHistories,
    required this.benchmarkTicker,
    required this.benchmarkHistory,
    required this.monthlyIncome,
  });
}

Future<AnalysesSnapshot> loadAnalysesSnapshot(String vaultPath) async {
  // Un compte/passif rattaché à une entité professionnelle (`entityId` non
  // nul) est hors du patrimoine personnel analysé ici (risque, diversification,
  // comparaison à un benchmark...) — même filtre que `dashboard_screen.dart`,
  // pour rester cohérent avec ce que le Dashboard compte dans le
  // "Patrimoine net" personnel.
  final accounts = (await InvestmentsRepository(vaultPath).listAll())
      .where((a) => a.entityId == null)
      .toList();
  final liabilities = (await LiabilitiesRepository(vaultPath).listAll())
      .where((l) => l.entityId == null)
      .toList();
  final priceHistories = await loadAllPriceHistories(vaultPath, accounts);
  final settings = await AnalysesSettingsRepository(vaultPath).load();

  var benchmarkHistory = <PricePoint>[];
  final ticker = settings.benchmarkTicker;
  if (ticker != null && ticker.isNotEmpty) {
    // Sans `neededSince`, `syncIfNeeded` ne redemande que depuis
    // aujourd'hui (voir sa documentation) : la toute première synchro du
    // benchmark ne récupérait donc qu'un jour de cours, jamais assez pour
    // couvrir les dates de transaction réelles — indispensable à la
    // comparaison pondérée par les flux de trésorerie (voir
    // `analyses_screen.dart`'s calcul d'alpha).
    final result = await PriceHistoryRepository(vaultPath).syncIfNeeded(
      '$benchmarkCacheKeyPrefix$ticker',
      ticker,
      neededSince: earliestTransactionDateAcrossAccounts(accounts),
    );
    benchmarkHistory = result.points;
  }

  final now = DateTime.now();
  final trackingMonth = await BudgetTrackingRepository(
    vaultPath,
  ).load(now.year, now.month);
  final monthlyIncome = trackingMonth.totalRevenuesRealite;

  return AnalysesSnapshot(
    accounts: accounts,
    liabilities: liabilities,
    priceHistories: priceHistories,
    benchmarkTicker: ticker,
    benchmarkHistory: benchmarkHistory,
    monthlyIncome: monthlyIncome > 0 ? monthlyIncome : null,
  );
}
