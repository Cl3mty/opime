import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../../core/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../liabilities/liabilities_models.dart';
import '../../liabilities/liabilities_repository.dart';
import '../complete_patrimoine_dialog.dart' show showCompletePatrimoineDialog;
import '../patrimoine_refresh_controller.dart';

/// Section "Crédits liés" d'un bien immobilier — affiche tous les
/// [Liability] dont [Liability.linkedInvestmentId] pointe vers ce bien
/// (typiquement un prêt immobilier et/ou un crédit travaux, rien n'empêche
/// techniquement d'en lier plusieurs des deux), avec une action pour délier
/// chacun ; propose en plus de lier un crédit existant non rattaché ou d'en
/// créer un nouveau déjà rattaché. Alimente la rentabilité (onglet
/// Rentabilité) avec le(s) vrai(s) prêt(s) plutôt qu'une saisie manuelle.
class RealEstateLoanLinkSection extends StatefulWidget {
  final String vaultPath;
  final String investmentId;

  /// Signal global de mutation du patrimoine — un crédit créé ailleurs
  /// pendant que cette section est déjà montée (ex : depuis le bouton "+"
  /// de la TopBar, sans repasser par cette page) doit apparaître comme
  /// candidat sans que l'utilisateur ait à quitter puis revenir sur le
  /// bien (même motif que `RealPassifDetailScreen`).
  final PatrimoineRefreshController patrimoineRefreshController;

  const RealEstateLoanLinkSection({
    super.key,
    required this.vaultPath,
    required this.investmentId,
    required this.patrimoineRefreshController,
  });

  @override
  State<RealEstateLoanLinkSection> createState() =>
      _RealEstateLoanLinkSectionState();
}

class _RealEstateLoanLinkSectionState
    extends State<RealEstateLoanLinkSection> {
  late final LiabilitiesRepository _repo = LiabilitiesRepository(
    widget.vaultPath,
  );
  bool _loading = true;
  List<Liability> _liabilities = const [];

  @override
  void initState() {
    super.initState();
    widget.patrimoineRefreshController.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.patrimoineRefreshController.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _repo.listAll();
    if (!mounted) return;
    setState(() {
      _liabilities = all;
      _loading = false;
    });
  }

  List<Liability> get _linkedLoans => [
    for (final liability in _liabilities)
      if (liability.linkedInvestmentId == widget.investmentId) liability,
  ];

  /// N'importe quel crédit ni lié à ce bien ni à un autre — un crédit
  /// travaux, par exemple, est un [LiabilityType.creditAutre] comme un
  /// autre (pas de type dédié), donc pas de filtre par type ici : seul
  /// [Liability.linkedInvestmentId] détermine ce qui est déjà pris.
  List<Liability> get _linkableCandidates => [
    for (final liability in _liabilities)
      if (liability.linkedInvestmentId == null) liability,
  ];

  Future<void> _link(Liability liability) async {
    await _repo.saveLiability(
      liability.copyWith(linkedInvestmentId: widget.investmentId),
    );
    await _load();
    // Prévient les autres pages ouvertes (ex : le détail de ce crédit dans
    // Passifs) que son lien a changé.
    widget.patrimoineRefreshController.notifyChanged();
  }

  Future<void> _unlink(Liability liability) async {
    await _repo.saveLiability(liability.copyWith(linkedInvestmentId: null));
    await _load();
    widget.patrimoineRefreshController.notifyChanged();
  }

  void _openLinkMenu(BuildContext anchorContext) {
    final candidates = _linkableCandidates;
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.topStart,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 240),
        child: DropdownMenu(
          children: [
            for (final liability in candidates)
              MenuButton(
                leading: const Icon(LucideIcons.landmark),
                trailing: shadcn.Text(
                  displayEuros(liability.remainingBalance, false),
                ).muted().xSmall(),
                onPressed: (_) => _link(liability),
                child: shadcn.Text(liability.name),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndLink(LiabilityType type) async {
    await showCompletePatrimoineDialog(
      context,
      vaultPath: widget.vaultPath,
      onCompleted: () {
        unawaited(_load());
        // Un nouveau passif change le patrimoine total (contrairement à
        // lier/délier un crédit déjà existant) : les autres pages ouvertes
        // (Dashboard, Passifs...) doivent le refléter aussi.
        widget.patrimoineRefreshController.notifyChanged();
      },
      initialLiabilityType: type,
      initialLinkedInvestmentId: widget.investmentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final linked = _linkedLoans;
    final candidates = _linkableCandidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final liability in linked) ...[
          _LinkedLoanRow(liability: liability, onUnlink: () => _unlink(liability)),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            if (candidates.isNotEmpty)
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => _openLinkMenu(context),
                  child: _LinkAction(
                    icon: LucideIcons.link,
                    label: l10n.real_estate_link_existing_loan,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _createAndLink(LiabilityType.pretImmobilier),
              child: _LinkAction(
                icon: LucideIcons.plus,
                label: l10n.real_estate_create_mortgage_loan,
                color: theme.colorScheme.primary,
              ),
            ),
            GestureDetector(
              // Un crédit travaux n'est pas un type dédié : juste un
              // `creditAutre` créé (et nommé) depuis ce raccourci.
              onTap: () => _createAndLink(LiabilityType.creditAutre),
              child: _LinkAction(
                icon: LucideIcons.plus,
                label: l10n.real_estate_create_work_loan,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkedLoanRow extends StatelessWidget {
  final Liability liability;
  final VoidCallback onUnlink;

  const _LinkedLoanRow({required this.liability, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(
          LucideIcons.landmark,
          size: 16,
          color: theme.colorScheme.mutedForeground,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: shadcn.Text(
            l10n.real_estate_linked_loan_summary(
              liability.name,
              // `LiabilityType.label` (`liabilities_models.dart`) n'est pas
              // encore traduit — hors du périmètre de ce fichier, reste en
              // français jusqu'à ce que ce getter partagé le soit.
              liability.type.label,
              displayEuros(liability.remainingBalance, false),
            ),
          ).small(),
        ),
        IconButton.ghost(
          icon: const Icon(LucideIcons.unlink, size: 14),
          onPressed: onUnlink,
        ),
      ],
    );
  }
}

class _LinkAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LinkAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        shadcn.Text(label, style: TextStyle(color: color)).small(),
      ],
    );
  }
}
