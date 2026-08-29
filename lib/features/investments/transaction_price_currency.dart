import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart' show formatEuros, parseDecimal;
import 'currency_data.dart';
import 'currency_format.dart';
import 'investments_models.dart';
import 'price_history_repository.dart';
import 'yahoo_finance_client.dart' show YahooFinanceClient;

/// Paire Yahoo Finance à interroger pour résoudre le taux de change de
/// [code] vers l'euro. Un stablecoin ([kKnownStablecoins]) est une crypto,
/// pas une devise fiat : sa paire se résout comme un ticker crypto
/// (`TICKER-EUR`, voir [YahooFinanceClient.resolveCryptoSymbol]) — la paire
/// fiat classique `TICKERAUR=X` n'existe pas pour un stablecoin sur Yahoo
/// Finance (elle retombait silencieusement sur la saisie manuelle, alors
/// qu'un vrai cours y est disponible). Extrait en fonction pure (testable
/// sans réseau) plutôt que gardé inline dans `_resolveAutoRate`.
String fxPairFor(String code) {
  final normalized = code.trim().toUpperCase();
  return kKnownStablecoins.contains(normalized)
      ? YahooFinanceClient().resolveCryptoSymbol(normalized)
      : '${normalized}EUR=X';
}

/// Devise et taux de change d'une transaction en cours de saisie
/// (formulaire "Ajouter une transaction" de `InvestmentDetailView` et
/// `_TransactionStep` du flux de complétion) : le prix unitaire est saisi
/// dans la devise de cotation du titre (EUR par défaut — le prix est alors
/// déjà en euros — ou USD pour META, GBP pour une action londonienne...),
/// et converti en euros au taux de change via [Transaction.fxRateToEur].
///
/// Le taux est résolu automatiquement depuis Yahoo Finance (paire
/// `<devise>EUR=X`, mise en cache localement par [PriceHistoryRepository]
/// comme n'importe quel historique de cours — une seule requête par jour et
/// par paire), avec repli sur la saisie manuelle quand la résolution échoue
/// (hors ligne, API indisponible) ou pour corriger un taux jugé inexact.
class TransactionPriceCurrencyController extends ChangeNotifier {
  TransactionPriceCurrencyController({required String vaultPath})
    : _priceRepo = PriceHistoryRepository(vaultPath);

  final PriceHistoryRepository _priceRepo;

  String _currency = 'EUR';

  /// `true` pendant la résolution automatique du taux sur Yahoo Finance —
  /// l'UI affiche un indicateur au lieu du taux.
  bool _fxLoading = false;

  /// `true` quand le taux est saisi manuellement (repli réseau ou
  /// correction) — l'UI affiche le champ de saisie au lieu du rappel.
  bool _manual = false;

  /// Taux auto-résolu (`1 _currency = X €`), ou `null` avant résolution ou
  /// si elle a échoué.
  double? _fxRateToEur;

  final _manualController = TextEditingController();

  String get currency => _currency;

  /// La devise courante est-elle autre que l'euro (donc un taux de change à
  /// résoudre/saisir) ?
  bool get isForeign => _currency != 'EUR';

  bool get fxLoading => _fxLoading;
  bool get manual => _manual;
  double? get fxRateToEur => _fxRateToEur;
  TextEditingController get manualController => _manualController;

  /// Taux à utiliser à la sauvegarde : le taux auto-résolu, ou le taux saisi
  /// manuellement — `null` si aucun n'est disponible (devise étrangère sans
  /// taux encore), 1 pour l'euro. C'est ce que lit le commit des formulaires
  /// pour construire `Transaction.fxRateToEur`.
  double? get resolvedRate {
    if (!isForeign) return 1.0;
    if (_fxRateToEur != null) return _fxRateToEur;
    final manual = parseDecimal(_manualController.text);
    return (manual == null || manual <= 0) ? null : manual;
  }

  /// Change la devise de cotation et relance la résolution automatique du
  /// taux — sauf pour l'euro, qui n'appelle aucun taux.
  Future<void> selectCurrency(String code) async {
    _currency = code;
    _fxRateToEur = null;
    _fxLoading = code != 'EUR';
    _manual = false;
    _manualController.clear();
    notifyListeners();
    if (code != 'EUR') await _resolveAutoRate(code);
  }

  /// Rétablit l'état depuis une devise/taux déjà enregistrés (édition d'une
  /// transaction, ou d'un prix d'entrée de position à effet de levier —
  /// voir `leveraged_position_dialog.dart`) : repris tels quels
  /// (historiquement exacts), sans nouvel appel réseau. Signature en
  /// valeurs brutes plutôt qu'un `Transaction` complet : réutilisable par
  /// n'importe quel autre champ prix/devise du même genre.
  void loadFrom({required String currency, required double? fxRateToEur}) {
    _currency = currency;
    _fxRateToEur = currency == 'EUR' ? null : fxRateToEur;
    _fxLoading = false;
    _manual = false;
    _manualController.clear();
    notifyListeners();
  }

  /// Réinitialise à l'euro (nouvelle transaction, changement d'investissement).
  void reset() {
    _currency = 'EUR';
    _fxRateToEur = null;
    _fxLoading = false;
    _manual = false;
    _manualController.clear();
    notifyListeners();
  }

  /// Bascule en saisie manuelle du taux (repli réseau, correction...),
  /// pré-remplie du taux auto-résolu pour faciliter la retouche.
  void enableManual() {
    _manual = true;
    if (_fxRateToEur != null) {
      _manualController.text = formatFxRate(_fxRateToEur!);
    }
    notifyListeners();
  }

  /// Retourne à la résolution automatique (annulation d'une correction
  /// manuelle) : relance une recherche et, si elle réussit, remplace le
  /// taux saisi.
  Future<void> enableAuto() async {
    if (_currency == 'EUR') return;
    _manual = false;
    _fxRateToEur = null;
    _fxLoading = true;
    _manualController.clear();
    notifyListeners();
    await _resolveAutoRate(_currency);
  }

  Future<void> _resolveAutoRate(String code) async {
    final pair = fxPairFor(code);
    final result = await _priceRepo.syncIfNeeded(
      pair,
      pair,
      // Un taux (1 JPY ≈ 0,006 €) a besoin d'une précision au-delà du
      // centime — voir `formatFxRate`.
      round: false,
    );
    if (result.points.isNotEmpty) {
      _fxRateToEur = result.points.last.close;
    } else {
      // Aucun taux disponible (premier lancement hors ligne, API
      // indisponible) : repli sur la saisie manuelle.
      _manual = true;
    }
    _fxLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }
}

/// Sélecteur de devise accolé au champ "Prix unitaire" d'une transaction
/// (voir `_CreateTransactionForm` et `_TransactionStep`) : EUR par défaut —
/// le prix tapé est alors déjà en euros — ou la devise de cotation du titre
/// (USD, GBP...), le prix étant saisi dans cette devise et converti en euros
/// via [TransactionPriceCurrencyController].
class TransactionPriceCurrencySelect extends StatelessWidget {
  final TransactionPriceCurrencyController controller;

  /// Options supplémentaires ajoutées après [kKnownCurrencies] — les
  /// stablecoins ([kKnownStablecoins]) pour une transaction crypto, afin de
  /// permettre "acheté X SOL pour Y USDC" en plus des devises classiques.
  /// Vide par défaut.
  final List<String> extraOptions;

  const TransactionPriceCurrencySelect({
    super.key,
    required this.controller,
    this.extraOptions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Select<String>(
        value: controller.currency,
        constraints: const BoxConstraints(minWidth: 92),
        onChanged: (code) {
          if (code != null) controller.selectCurrency(code);
        },
        itemBuilder: (context, code) => shadcn.Text(code),
        popup: (context) => SelectPopup(
          items: SelectItemList(
            children: [
              for (final code in kKnownCurrencies)
                SelectItemButton(value: code, child: shadcn.Text(code)),
              for (final code in extraOptions)
                SelectItemButton(value: code, child: shadcn.Text(code)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zone sous le champ prix d'une transaction en devise étrangère : rappelle
/// le taux de change appliqué (auto ou saisi manuellement) et le montant
/// converti en euros — masquée pour une transaction en euros. Voir
/// `_CreateTransactionForm` et `_TransactionStep`.
class TransactionFxRateArea extends StatelessWidget {
  final TransactionPriceCurrencyController controller;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  const TransactionFxRateArea({
    super.key,
    required this.controller,
    required this.quantityController,
    required this.priceController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [controller, quantityController, priceController],
      ),
      builder: (context, _) {
        if (!controller.isForeign) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.fxLoading)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    shadcn.Text('Recherche du taux de change…')
                        .muted()
                        .xSmall(),
                  ],
                )
              else if (controller.manual)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.manualController,
                        placeholder: shadcn.Text(
                          'Taux de change (1 ${controller.currency} en €)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    // Un taux auto avait été résolu avant la bascule
                    // manuelle : on peut y revenir.
                    if (controller.fxRateToEur != null) ...[
                      const SizedBox(width: 8),
                      GhostButton(
                        onPressed: controller.enableAuto,
                        child: const shadcn.Text('Automatique'),
                      ),
                    ],
                  ],
                )
              else ...[
                Row(
                  children: [
                    shadcn.Text(
                      '1 ${controller.currency} ≈ '
                      '${formatFxRate(controller.fxRateToEur!)} €',
                    ).muted().xSmall(),
                    const SizedBox(width: 8),
                    GhostButton(
                      onPressed: controller.enableManual,
                      child: const shadcn.Text('Taux manuel'),
                    ),
                  ],
                ),
              ],
              // Montant converti en euros, dès que quantité, prix et taux
              // sont renseignés — pour confirmer d'un coup d'œil la
              // conversion au moment de la saisie.
              if (!controller.fxLoading && controller.resolvedRate != null)
                ..._amountHintWidgets(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _amountHintWidgets() {
    final quantity = parseDecimal(quantityController.text);
    final price = parseDecimal(priceController.text);
    final rate = controller.resolvedRate;
    if (quantity == null || quantity <= 0 || price == null || price <= 0) {
      return const [];
    }
    if (rate == null) return const [];
    final amount = quantity * price * rate;
    return [
      const SizedBox(height: 6),
      shadcn.Text('Montant ≈ ${formatEuros(amount)}').muted().xSmall(),
    ];
  }
}
