import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../../core/money_format.dart';
import '../../liabilities/liabilities_models.dart';
import '../../liabilities/liabilities_repository.dart';

/// Section "Prêt lié" d'un bien immobilier — affiche le [Liability] dont
/// [Liability.linkedInvestmentId] pointe vers ce bien, s'il y en a un, avec
/// une action pour le délier ; sinon propose de lier un prêt immobilier
/// existant qui n'est pas déjà rattaché à un autre bien. Alimente la
/// rentabilité (onglet Rentabilité, à venir) avec le vrai prêt plutôt
/// qu'une saisie manuelle.
class RealEstateLoanLinkSection extends StatefulWidget {
  final String vaultPath;
  final String investmentId;

  const RealEstateLoanLinkSection({
    super.key,
    required this.vaultPath,
    required this.investmentId,
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
    _load();
  }

  Future<void> _load() async {
    final all = await _repo.listAll();
    if (!mounted) return;
    setState(() {
      _liabilities = all;
      _loading = false;
    });
  }

  Liability? get _linked {
    for (final liability in _liabilities) {
      if (liability.linkedInvestmentId == widget.investmentId) {
        return liability;
      }
    }
    return null;
  }

  List<Liability> get _linkableCandidates => [
    for (final liability in _liabilities)
      if (liability.type == LiabilityType.pretImmobilier &&
          liability.linkedInvestmentId == null)
        liability,
  ];

  Future<void> _link(Liability liability) async {
    await _repo.saveLiability(
      liability.copyWith(linkedInvestmentId: widget.investmentId),
    );
    await _load();
  }

  Future<void> _unlink(Liability liability) async {
    await _repo.saveLiability(liability.copyWith(linkedInvestmentId: null));
    await _load();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final linked = _linked;
    final theme = Theme.of(context);
    if (linked != null) {
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
              '${linked.name} · ${displayEuros(linked.remainingBalance, false)} '
              'restant dû',
            ).small(),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.unlink, size: 14),
            onPressed: () => _unlink(linked),
          ),
        ],
      );
    }
    final candidates = _linkableCandidates;
    if (candidates.isEmpty) {
      return shadcn.Text(
        'Aucun prêt immobilier disponible à lier.',
      ).muted().xSmall();
    }
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _openLinkMenu(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.link,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            shadcn.Text(
              'Lier un prêt existant',
              style: TextStyle(color: theme.colorScheme.primary),
            ).small(),
          ],
        ),
      ),
    );
  }
}
