import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../../core/money_format.dart' show displayEuros, parseDecimal;
import '../../../core/ui/frosted_card.dart';
import '../../../core/ui/opime_date_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../investments_models.dart';
import '../investments_repository.dart';

/// Ouvre l'édition d'un arbitrage — les DEUX transactions liées (vente
/// source, achat destination, voir [Transaction.linkedTransactionId])
/// modifiées ensemble en une seule opération, plutôt que deux formulaires
/// d'édition génériques séparés. Ce dernier existait avant ce dialogue et
/// reste un piège : chaque formulaire reconstruit sa `Transaction` sans
/// connaître `type`/`linkedTransactionId` de l'autre jambe, un enregistrement
/// détache donc silencieusement la paire (elle redevient deux transactions
/// "Vente"/"Achat" ordinaires, sans lien) — d'où ce dialogue dédié, qui ne
/// permet de changer que la date, la quantité vendue et les deux prix, tout
/// en réécrivant les deux transactions à l'identique sur le reste
/// (id, type, lien). Les positions concernées (source/destination), elles,
/// ne sont volontairement pas réassignables ici : ce serait recréer le
/// flux de `transfer_arbitrage_dialog.dart`, déjà disponible via "Arbitrer
/// vers un autre titre" si l'utilisateur veut vraiment changer de titre.
Future<void> showEditArbitrageDialog(
  BuildContext context, {
  required String vaultPath,
  required InvestmentAccount account,
  required Investment sellInvestment,
  required Transaction sellTransaction,
  required Investment buyInvestment,
  required Transaction buyTransaction,
  required Future<void> Function() onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _EditArbitrageDialog(
      vaultPath: vaultPath,
      account: account,
      sellInvestment: sellInvestment,
      sellTransaction: sellTransaction,
      buyInvestment: buyInvestment,
      buyTransaction: buyTransaction,
      onChanged: onChanged,
    ),
  );
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

/// Arrondi à 4 décimales pour l'AFFICHAGE seul — voir
/// `transfer_arbitrage_dialog.dart`'s équivalent.
double _roundForDisplay(double value) => (value * 10000).round() / 10000;

class _EditArbitrageDialog extends StatefulWidget {
  final String vaultPath;
  final InvestmentAccount account;
  final Investment sellInvestment;
  final Transaction sellTransaction;
  final Investment buyInvestment;
  final Transaction buyTransaction;
  final Future<void> Function() onChanged;

  const _EditArbitrageDialog({
    required this.vaultPath,
    required this.account,
    required this.sellInvestment,
    required this.sellTransaction,
    required this.buyInvestment,
    required this.buyTransaction,
    required this.onChanged,
  });

  @override
  State<_EditArbitrageDialog> createState() => _EditArbitrageDialogState();
}

class _EditArbitrageDialogState extends State<_EditArbitrageDialog> {
  late final InvestmentsRepository _repo;
  DateTime? _date;
  late final TextEditingController _quantityController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _buyPriceController;

  /// Quantité que la vente pourrait atteindre si elle était retirée de
  /// l'historique — plafond de validation cohérent avec une MODIFICATION
  /// (contrairement à une nouvelle vente, celle-ci contribue déjà à
  /// [Investment.quantityHeld], il faut donc la réintégrer avant de
  /// comparer).
  late final double _maxSellable;

  @override
  void initState() {
    super.initState();
    _repo = InvestmentsRepository(widget.vaultPath);
    _date = widget.sellTransaction.date;
    _quantityController = TextEditingController(
      text: _formatNumber(widget.sellTransaction.quantity),
    );
    _sellPriceController = TextEditingController(
      text: _formatNumber(widget.sellTransaction.unitPrice),
    );
    _buyPriceController = TextEditingController(
      text: _formatNumber(widget.buyTransaction.unitPrice),
    );
    _maxSellable =
        widget.sellInvestment.quantityHeld + widget.sellTransaction.quantity;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _sellPriceController.dispose();
    _buyPriceController.dispose();
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

  String _validationError(
    AppLocalizations l10n, {
    required double? quantity,
    required double? sellPrice,
    required double? buyPrice,
  }) {
    if (quantity == null || quantity <= 0) {
      return l10n.investments_error_quantity_must_be_positive;
    }
    if (quantity > _maxSellable + 1e-9) {
      return l10n.investments_error_quantity_exceeds_sellable(
        _formatNumber(quantity),
        _formatNumber(_maxSellable),
      );
    }
    if (sellPrice == null || sellPrice <= 0) {
      return l10n.investments_error_sell_price_must_be_positive;
    }
    if (buyPrice == null || buyPrice <= 0) {
      return l10n.investments_error_buy_price_must_be_positive;
    }
    return l10n.investments_error_date_required;
  }

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final date = _date;
    final quantity = parseDecimal(_quantityController.text);
    final sellPrice = parseDecimal(_sellPriceController.text);
    final buyPrice = parseDecimal(_buyPriceController.text);
    if (date == null ||
        quantity == null ||
        quantity <= 0 ||
        quantity > _maxSellable + 1e-9 ||
        sellPrice == null ||
        sellPrice <= 0 ||
        buyPrice == null ||
        buyPrice <= 0) {
      _showToast(
        title: l10n.investments_edit_impossible_title,
        subtitle: _validationError(
          l10n,
          quantity: quantity,
          sellPrice: sellPrice,
          buyPrice: buyPrice,
        ),
      );
      return;
    }
    // Voir `transfer_arbitrage_dialog.dart`'s `_commitArbitrage` : la
    // quantité achetée est toujours dérivée du produit de la vente, jamais
    // saisie directement, pour garantir que l'arbitrage ne fait ni apport
    // ni retrait de cash.
    final destQuantity = (quantity * sellPrice) / buyPrice;

    final updatedSellTransaction = Transaction(
      id: widget.sellTransaction.id,
      date: date,
      isBuy: false,
      quantity: quantity,
      unitPrice: sellPrice,
      type: TransactionType.arbitrage,
      linkedTransactionId: widget.buyTransaction.id,
    );
    final updatedBuyTransaction = Transaction(
      id: widget.buyTransaction.id,
      date: date,
      isBuy: true,
      quantity: destQuantity,
      unitPrice: buyPrice,
      type: TransactionType.arbitrage,
      linkedTransactionId: widget.sellTransaction.id,
    );

    final updatedSellInvestment = widget.sellInvestment.copyWith(
      transactions: [
        for (final t in widget.sellInvestment.transactions)
          if (t.id == widget.sellTransaction.id) updatedSellTransaction else t,
      ],
    );
    final updatedBuyInvestment = widget.buyInvestment.copyWith(
      transactions: [
        for (final t in widget.buyInvestment.transactions)
          if (t.id == widget.buyTransaction.id) updatedBuyTransaction else t,
      ],
    );
    // Toujours le même compte (un arbitrage ne quitte jamais son compte
    // d'origine, voir `transfer_arbitrage_dialog.dart`) : une seule
    // écriture couvre les deux positions.
    final updatedAccount = widget.account.copyWith(
      investments: [
        for (final i in widget.account.investments)
          if (i.id == updatedSellInvestment.id)
            updatedSellInvestment
          else if (i.id == updatedBuyInvestment.id)
            updatedBuyInvestment
          else
            i,
      ],
    );

    try {
      await _repo.saveAccount(updatedAccount);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        title: l10n.investments_edit_impossible_title,
        subtitle: l10n.investments_save_error(e.toString()),
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
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
                          l10n.investments_edit_arbitrage_title,
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
                    '${widget.sellInvestment.label} → '
                    '${widget.buyInvestment.label}',
                  ).muted().xSmall(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledField(
                          l10n.investments_field_quantity,
                          _quantityController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _labeledField(
                          l10n.investments_field_sell_price,
                          _sellPriceController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _labeledField(
                    l10n.investments_field_buy_price,
                    _buyPriceController,
                  ),
                  const SizedBox(height: 4),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _quantityController,
                      _sellPriceController,
                      _buyPriceController,
                    ]),
                    builder: (context, _) {
                      final quantity = parseDecimal(_quantityController.text);
                      final sellPrice = parseDecimal(
                        _sellPriceController.text,
                      );
                      final buyPrice = parseDecimal(_buyPriceController.text);
                      final amount = (quantity != null && sellPrice != null)
                          ? quantity * sellPrice
                          : null;
                      final destQuantity =
                          (amount != null && buyPrice != null && buyPrice > 0)
                          ? amount / buyPrice
                          : null;
                      return shadcn.Text(
                        amount == null
                            ? l10n.investments_amount_placeholder
                            : destQuantity == null
                            ? l10n.investments_amount_value(
                                displayEuros(amount, false),
                              )
                            : l10n.investments_amount_with_bought_quantity(
                                displayEuros(amount, false),
                                _formatNumber(
                                  _roundForDisplay(destQuantity),
                                ),
                              ),
                      ).muted().xSmall();
                    },
                  ),
                  const SizedBox(height: 8),
                  shadcn.Text(l10n.common_date).muted().xSmall(),
                  const SizedBox(height: 4),
                  OpimeDatePicker(
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: _commit,
                        child: shadcn.Text(l10n.common_save),
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
