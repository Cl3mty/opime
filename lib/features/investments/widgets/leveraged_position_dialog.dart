import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:opime/l10n/app_localizations.dart';
import '../../../core/money_format.dart' show displayEuros, parseDecimal;
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/opime_date_picker.dart';
import '../currency_data.dart' show kKnownStablecoins;
import '../investments_models.dart';
import '../investments_repository.dart';
import '../leveraged_position.dart';
import '../transaction_price_currency.dart';
import '../yahoo_finance_client.dart' show kKnownCryptoTickers;

/// Ouvre l'ajout ou l'édition d'une position à effet de levier —
/// [existing] `null` pour une création, renseigné pour une édition (tous
/// les champs pré-remplis). Un seul formulaire pour les deux cas, comme
/// `edit_arbitrage_dialog.dart` évite d'avoir un formulaire de création et
/// un formulaire d'édition qui divergent avec le temps.
Future<void> showLeveragedPositionDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  LeveragedPosition? existing,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LeveragedPositionDialog(
      vaultPath: vaultPath,
      account: account,
      existing: existing,
      onChanged: onChanged,
    ),
  );
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class _LeveragedPositionDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final LeveragedPosition? existing;
  final Future<void> Function() onChanged;

  const _LeveragedPositionDialog({
    required this.vaultPath,
    required this.account,
    required this.existing,
    required this.onChanged,
  });

  @override
  State<_LeveragedPositionDialog> createState() =>
      _LeveragedPositionDialogState();
}

class _LeveragedPositionDialogState extends State<_LeveragedPositionDialog> {
  late final InvestmentsRepository _repo;
  bool get _isEdit => widget.existing != null;

  /// `true` : le marché se choisit dans [kKnownCryptoTickers] (comme une
  /// position spot classique — voir `investment_identifier_field.dart`),
  /// pour que le cours automatique (voir `price_refresh_service.dart`)
  /// puisse le résoudre de façon fiable. `false` (Actions & Fonds — CFD/
  /// action sur marge) : texte libre, pas de ticker Yahoo fiable pour un
  /// dérivé sur marge.
  bool get _isCrypto => widget.account.assetClass == AssetClass.crypto;

  late final TextEditingController _marketController;
  late PositionSide _side;
  late final TextEditingController _leverageController;
  late final TextEditingController _sizeController;
  late final TextEditingController _entryPriceController;
  late final TransactionPriceCurrencyController _priceCurrencyController;
  late final TextEditingController _takeProfitController;
  late final TextEditingController _stopLossController;
  late final TextEditingController _noteController;
  DateTime? _openedAt;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    final existing = widget.existing;
    _marketController = TextEditingController(text: existing?.market ?? '');
    _side = existing?.side ?? PositionSide.long;
    _leverageController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.leverage),
    );
    _sizeController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.size),
    );
    _entryPriceController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.entryPrice),
    );
    _priceCurrencyController = TransactionPriceCurrencyController(
      vaultPath: widget.vaultPath,
    );
    if (existing != null) {
      _priceCurrencyController.loadFrom(
        currency: existing.entryPriceCurrency,
        fxRateToEur: existing.entryPriceFxRateToEur,
      );
    }
    _takeProfitController = TextEditingController(
      text: existing?.takeProfit == null
          ? ''
          : _formatNumber(existing!.takeProfit!),
    );
    _stopLossController = TextEditingController(
      text: existing?.stopLoss == null
          ? ''
          : _formatNumber(existing!.stopLoss!),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    final today = DateTime.now();
    _openedAt =
        existing?.openedAt ?? DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _marketController.dispose();
    _leverageController.dispose();
    _sizeController.dispose();
    _entryPriceController.dispose();
    _priceCurrencyController.dispose();
    _takeProfitController.dispose();
    _stopLossController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showToast({required String title, required String subtitle}) {
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(title),
          subtitle: shadcn.Text(subtitle),
        ),
      ),
    );
  }

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final market = _marketController.text.trim();
    final leverage = parseDecimal(_leverageController.text);
    final size = parseDecimal(_sizeController.text);
    final entryPrice = parseDecimal(_entryPriceController.text);
    // Hors crypto (Actions & Fonds), le prix d'entrée reste toujours en
    // euros — pas de sélecteur affiché, voir [_isCrypto].
    final entryPriceCurrency = _isCrypto
        ? _priceCurrencyController.currency
        : 'EUR';
    final entryPriceFxRateToEur = entryPriceCurrency == 'EUR'
        ? 1.0
        : _priceCurrencyController.resolvedRate;
    final takeProfit = parseDecimal(_takeProfitController.text);
    final stopLoss = parseDecimal(_stopLossController.text);
    final openedAt = _openedAt;

    String? error;
    if (market.isEmpty) {
      error = l10n.investments_leveraged_market_required_error;
    } else if (leverage == null || leverage <= 0) {
      error = l10n.investments_leveraged_leverage_positive_error;
    } else if (size == null || size <= 0) {
      error = l10n.investments_leveraged_size_positive_error;
    } else if (entryPrice == null || entryPrice <= 0) {
      error = l10n.investments_leveraged_entry_price_positive_error;
    } else if (entryPriceFxRateToEur == null || entryPriceFxRateToEur <= 0) {
      error = l10n.investments_leveraged_entry_fx_rate_required_error;
    } else if (openedAt == null) {
      error = l10n.investments_leveraged_opening_date_required_error;
    }
    if (error != null) {
      _showToast(
        title: l10n.investments_leveraged_save_impossible_title,
        subtitle: error,
      );
      return;
    }

    final position = (widget.existing ?? LeveragedPosition(
      market: market,
      side: _side,
      leverage: leverage!,
      size: size!,
      entryPrice: entryPrice!,
      openedAt: openedAt,
    )).copyWith(
      market: market,
      side: _side,
      leverage: leverage,
      size: size,
      entryPrice: entryPrice,
      entryPriceCurrency: entryPriceCurrency,
      entryPriceFxRateToEur: entryPriceFxRateToEur,
      takeProfit: takeProfit,
      stopLoss: stopLoss,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final updatedAccount = widget.account.copyWith(
      leveragedPositions: [
        for (final p in widget.account.leveragedPositions)
          if (p.id != position.id) p,
        position,
      ],
    );

    try {
      await _repo.saveAccount(updatedAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_leveraged_save_impossible_title,
        subtitle: l10n.investments_save_error('$e'),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  Widget _labeledField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().xSmall(),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  /// Montant de la position/marge/prix de liquidation estimé, calculés à
  /// partir des champs déjà saisis — construit une position transitoire
  /// (jamais enregistrée) juste pour réutiliser les mêmes formules que le
  /// modèle ([LeveragedPosition.entryNotionalValue]/[LeveragedPosition
  /// .margin]/[LeveragedPosition.estimatedLiquidationPrice]) plutôt que de
  /// les dupliquer ici. Vide tant que taille/prix d'entrée/levier ne sont
  /// pas tous renseignés (ou que le taux de change d'une devise étrangère
  /// n'est pas encore résolu) — pas de calcul trompeur sur des champs
  /// incomplets.
  Widget _liveCalculations() {
    final l10n = AppLocalizations.of(context);
    final leverage = parseDecimal(_leverageController.text);
    final size = parseDecimal(_sizeController.text);
    final entryPrice = parseDecimal(_entryPriceController.text);
    if (leverage == null ||
        leverage <= 0 ||
        size == null ||
        size <= 0 ||
        entryPrice == null ||
        entryPrice <= 0) {
      return const SizedBox.shrink();
    }
    final entryPriceCurrency = _isCrypto
        ? _priceCurrencyController.currency
        : 'EUR';
    final entryPriceFxRateToEur = entryPriceCurrency == 'EUR'
        ? 1.0
        : _priceCurrencyController.resolvedRate;
    if (entryPriceFxRateToEur == null) return const SizedBox.shrink();

    final preview = LeveragedPosition(
      // Jamais enregistré, valeur sans importance ici.
      market: 'preview',
      side: _side,
      leverage: leverage,
      size: size,
      entryPrice: entryPrice,
      entryPriceCurrency: entryPriceCurrency,
      entryPriceFxRateToEur: entryPriceFxRateToEur,
    );
    final liquidation = preview.estimatedLiquidationPrice;
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        shadcn.Text(
          l10n.investments_leveraged_notional_amount(
            displayEuros(preview.entryNotionalValue, false),
          ),
        ).muted().xSmall(),
        shadcn.Text(
          l10n.investments_leveraged_margin(displayEuros(preview.margin, false)),
        ).muted().xSmall(),
        if (liquidation != null)
          shadcn.Text(
            l10n.investments_leveraged_estimated_liquidation(
              displayEuros(liquidation, false),
            ),
          ).muted().xSmall(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: shadcn.Text(
                          _isEdit
                              ? l10n.investments_leveraged_edit_title
                              : l10n.investments_leveraged_new_title,
                        ).large().semiBold(),
                      ),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isCrypto)
                    // Choisi dans la même liste qu'une position spot
                    // classique (voir `investment_identifier_field.dart`) :
                    // un ticker fiable, nécessaire pour que le cours
                    // automatique (`price_refresh_service.dart`) puisse le
                    // résoudre.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _marketController,
                      builder: (context, value, _) => Select<String>(
                        value: value.text.isEmpty ? null : value.text,
                        itemBuilder: (context, item) => shadcn.Text(item),
                        onChanged: (selected) {
                          if (selected != null) {
                            _marketController.text = selected;
                          }
                        },
                        popup: (context) => SelectPopup(
                          items: SelectItemList(
                            children: [
                              for (final ticker in kKnownCryptoTickers)
                                SelectItemButton(
                                  value: ticker,
                                  child: shadcn.Text(ticker),
                                ),
                            ],
                          ),
                        ),
                        placeholder: shadcn.Text(l10n.investments_market_placeholder),
                      ),
                    )
                  else
                    TextField(
                      controller: _marketController,
                      placeholder: shadcn.Text(l10n.investments_market_hint),
                      autofocus: !_isEdit,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shadcn.Text(l10n.investments_side_label).muted().xSmall(),
                            const SizedBox(height: 4),
                            Select<PositionSide>(
                              value: _side,
                              itemBuilder: (context, value) =>
                                  shadcn.Text(value.label),
                              onChanged: (v) {
                                if (v != null) setState(() => _side = v);
                              },
                              popup: (context) => SelectPopup(
                                items: SelectItemList(
                                  children: [
                                    for (final side in PositionSide.values)
                                      SelectItemButton(
                                        value: side,
                                        child: shadcn.Text(side.label),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _labeledField(
                          l10n.investments_leverage_hint,
                          _leverageController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledField(l10n.investments_size_label, _sizeController),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shadcn.Text(l10n.investments_entry_price_label).muted().xSmall(),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _entryPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                                // Devise ou stablecoin (USDC/USDT) du prix
                                // d'entrée, comme pour une transaction spot
                                // crypto — hors crypto (Actions & Fonds),
                                // toujours en euros, pas de sélecteur.
                                if (_isCrypto) ...[
                                  const SizedBox(width: 8),
                                  TransactionPriceCurrencySelect(
                                    controller: _priceCurrencyController,
                                    extraOptions: kKnownStablecoins,
                                  ),
                                ],
                              ],
                            ),
                            if (_isCrypto)
                              TransactionFxRateArea(
                                controller: _priceCurrencyController,
                                quantityController: _sizeController,
                                priceController: _entryPriceController,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Montant de la position et marge (taille × prix
                  // d'entrée ÷ levier) ainsi que le prix de liquidation
                  // estimé (marge isolée, sans marge de maintenance) —
                  // calculés en direct pendant la saisie, jamais tapés à la
                  // main (voir la doc de tête de `LeveragedPosition`).
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _sizeController,
                      _entryPriceController,
                      _leverageController,
                      _priceCurrencyController,
                    ]),
                    builder: (context, _) => _liveCalculations(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledField(
                          l10n.investments_take_profit_hint,
                          _takeProfitController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _labeledField(
                          l10n.investments_stop_loss_hint,
                          _stopLossController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  shadcn.Text(l10n.investments_opening_date_label).muted().xSmall(),
                  const SizedBox(height: 4),
                  OpimeDatePicker(
                    value: _openedAt,
                    onChanged: (d) => setState(() => _openedAt = d),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    placeholder: shadcn.Text(l10n.investments_note_hint),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: _commit,
                        child: shadcn.Text(
                          _isEdit ? l10n.common_save : l10n.common_add,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: shadcn.Text(l10n.common_cancel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre l'actualisation du cours/prix de liquidation/funding d'une
/// position — l'action la plus fréquente (contrairement à l'édition
/// complète), un petit formulaire dédié plutôt que de rouvrir tous les
/// champs de création. Même esprit que "Réestimer le cours"
/// (`position_detail_dialog.dart`'s `_showManualEstimateDialog`).
Future<void> showRefreshLeveragedPositionDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required LeveragedPosition position,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RefreshLeveragedPositionDialog(
      vaultPath: vaultPath,
      account: account,
      position: position,
      onChanged: onChanged,
    ),
  );
}

class _RefreshLeveragedPositionDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final LeveragedPosition position;
  final Future<void> Function() onChanged;

  const _RefreshLeveragedPositionDialog({
    required this.vaultPath,
    required this.account,
    required this.position,
    required this.onChanged,
  });

  @override
  State<_RefreshLeveragedPositionDialog> createState() =>
      _RefreshLeveragedPositionDialogState();
}

class _RefreshLeveragedPositionDialogState
    extends State<_RefreshLeveragedPositionDialog> {
  late final InvestmentsRepository _repo;
  late final TextEditingController _markPriceController;
  late final TextEditingController _liquidationPriceController;
  late final TextEditingController _fundingController;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _markPriceController = TextEditingController(
      text: widget.position.markPrice == null
          ? ''
          : _formatNumber(widget.position.markPrice!),
    );
    // Pré-rempli avec la valeur exacte déjà corrigée, sinon l'estimation
    // calculée (voir `LeveragedPosition.effectiveLiquidationPrice`) plutôt
    // qu'un champ vide — l'utilisateur peut accepter cette estimation
    // telle quelle ou la corriger avec la valeur exacte de son exchange.
    _liquidationPriceController = TextEditingController(
      text: widget.position.effectiveLiquidationPrice == null
          ? ''
          : _formatNumber(widget.position.effectiveLiquidationPrice!),
    );
    _fundingController = TextEditingController(
      text: _formatNumber(widget.position.cumulativeFunding),
    );
  }

  @override
  void dispose() {
    _markPriceController.dispose();
    _liquidationPriceController.dispose();
    _fundingController.dispose();
    super.dispose();
  }

  void _showToast({required String title, required String subtitle}) {
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(title),
          subtitle: shadcn.Text(subtitle),
        ),
      ),
    );
  }

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final markPrice = parseDecimal(_markPriceController.text);
    final liquidationPrice = parseDecimal(_liquidationPriceController.text);
    final funding = parseDecimal(_fundingController.text);
    if (markPrice == null || markPrice <= 0) {
      _showToast(
        title: l10n.investments_refresh_impossible_title,
        subtitle: l10n.investments_mark_price_positive_error,
      );
      return;
    }
    if (funding == null) {
      _showToast(
        title: l10n.investments_refresh_impossible_title,
        subtitle: l10n.investments_cumulative_funding_number_error,
      );
      return;
    }

    final updated = widget.position.copyWith(
      markPrice: markPrice,
      markPriceAt: DateTime.now(),
      liquidationPrice: liquidationPrice,
      cumulativeFunding: funding,
    );
    final updatedAccount = widget.account.copyWith(
      leveragedPositions: [
        for (final p in widget.account.leveragedPositions)
          if (p.id == updated.id) updated else p,
      ],
    );

    try {
      await _repo.saveAccount(updatedAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_refresh_impossible_title,
        subtitle: l10n.investments_save_error('$e'),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  Widget _labeledField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shadcn.Text(label).muted().xSmall(),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: shadcn.Text(
                        'Actualiser "${widget.position.market}"',
                      ).large().semiBold(),
                    ),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _labeledField('Cours actuel (mark price)', _markPriceController),
                const SizedBox(height: 8),
                _labeledField(
                  'Prix de liquidation',
                  _liquidationPriceController,
                ),
                const SizedBox(height: 8),
                _labeledField('Funding cumulé', _fundingController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: _commit,
                      child: const shadcn.Text('Actualiser'),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const shadcn.Text('Annuler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre la clôture d'une position — demande le prix de sortie, qui fige le
/// PnL réalisé ([LeveragedPosition.pnl] bascule alors sur [closePrice]
/// plutôt que [markPrice]). La position ne compte alors plus dans le
/// patrimoine (voir [LeveragedPosition.displayValue]) mais reste visible
/// dans une section "Positions fermées" séparée.
Future<void> showCloseLeveragedPositionDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required LeveragedPosition position,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CloseLeveragedPositionDialog(
      vaultPath: vaultPath,
      account: account,
      position: position,
      onChanged: onChanged,
    ),
  );
}

class _CloseLeveragedPositionDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final LeveragedPosition position;
  final Future<void> Function() onChanged;

  const _CloseLeveragedPositionDialog({
    required this.vaultPath,
    required this.account,
    required this.position,
    required this.onChanged,
  });

  @override
  State<_CloseLeveragedPositionDialog> createState() =>
      _CloseLeveragedPositionDialogState();
}

class _CloseLeveragedPositionDialogState
    extends State<_CloseLeveragedPositionDialog> {
  late final InvestmentsRepository _repo;
  late final TextEditingController _closePriceController;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _closePriceController = TextEditingController(
      text: widget.position.markPrice == null
          ? ''
          : _formatNumber(widget.position.markPrice!),
    );
  }

  @override
  void dispose() {
    _closePriceController.dispose();
    super.dispose();
  }

  void _showToast({required String title, required String subtitle}) {
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(title),
          subtitle: shadcn.Text(subtitle),
        ),
      ),
    );
  }

  Future<void> _commit() async {
    final closePrice = parseDecimal(_closePriceController.text);
    if (closePrice == null || closePrice <= 0) {
      _showToast(
        title: 'Clôture impossible',
        subtitle: 'Le prix de sortie doit être un nombre supérieur à 0.',
      );
      return;
    }

    final updated = widget.position.copyWith(
      closePrice: closePrice,
      closedAt: DateTime.now(),
    );
    final updatedAccount = widget.account.copyWith(
      leveragedPositions: [
        for (final p in widget.account.leveragedPositions)
          if (p.id == updated.id) updated else p,
      ],
    );

    try {
      await _repo.saveAccount(updatedAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: 'Clôture impossible',
        subtitle: 'Erreur lors de l\'enregistrement : $e',
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: shadcn.Text(
                        'Clôturer "${widget.position.market}"',
                      ).large().semiBold(),
                    ),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                shadcn.Text(
                  'Fige le PnL réalisé à ce prix de sortie. La position ne '
                  'compte plus dans le patrimoine ensuite, mais reste '
                  'visible dans "Positions fermées".',
                ).muted().xSmall(),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shadcn.Text('Prix de sortie').muted().xSmall(),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _closePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: _commit,
                      child: const shadcn.Text('Clôturer'),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const shadcn.Text('Annuler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
