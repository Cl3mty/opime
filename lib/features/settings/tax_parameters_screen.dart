import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../navigation/navigation_scope.dart';
import '../simulations/tax_parameters.dart';

/// Écran Réglages "Paramètres fiscaux" : barèmes, seuils et abattements
/// utilisés par les simulateurs (impôt sur le revenu, IFI, démembrement,
/// donation/succession — voir `tax_parameters.dart`). Chaque valeur est
/// éditable individuellement, avec son propre bouton de réinitialisation
/// vers la référence légale connue ([TaxParameters.defaults]) — pas de
/// réinitialisation groupée par section, pour ne jamais écraser une
/// personnalisation encore valide sous prétexte d'en corriger une seule.
///
/// Persisté par profil comme le reste de l'état des simulateurs (voir
/// `loadTaxParameters`/`saveTaxParameters`), lu par
/// `simulations_taxation_screen.dart`/`simulations_transmission_screen.dart`
/// à l'ouverture de chaque onglet concerné.
class TaxParametersScreen extends StatefulWidget {
  final String vaultPath;

  const TaxParametersScreen({super.key, required this.vaultPath});

  @override
  State<TaxParametersScreen> createState() => _TaxParametersScreenState();
}

class _TaxParametersScreenState extends State<TaxParametersScreen> {
  bool _loading = true;
  TaxParameters _params = TaxParameters.defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await loadTaxParameters(widget.vaultPath);
    if (!mounted) return;
    setState(() {
      _params = loaded;
      _loading = false;
    });
  }

  void _update(TaxParameters Function(TaxParameters current) fn) {
    final updated = fn(_params);
    setState(() => _params = updated);
    saveTaxParameters(widget.vaultPath, updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => NavigationScope.maybeOf(context)?.call('settings'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.chevronLeft, size: 18),
                  const SizedBox(width: 4),
                  const shadcn.Text('Réglages').small(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const shadcn.Text('Paramètres fiscaux').x2Large().semiBold(),
          const SizedBox(height: 8),
          const shadcn.Text(
            'Barèmes, seuils et abattements utilisés par les simulateurs '
            '(impôt sur le revenu, IFI, démembrement, donation et '
            'succession). Modifie une valeur ici si l\'État la révise, '
            'sans attendre une mise à jour du logiciel — chacune peut être '
            'réinitialisée individuellement à sa référence légale connue '
            'via l\'icône ↺ qui apparaît à côté d\'une valeur modifiée.',
          ).muted().small(),
          const SizedBox(height: 24),
          _buildIRSection(),
          const SizedBox(height: 16),
          _buildIFISection(),
          const SizedBox(height: 16),
          _buildDemembrementSection(),
          const SizedBox(height: 16),
          _buildDonationSection(),
          const SizedBox(height: 16),
          _buildPfuSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildIRSection() {
    return _TaxCard(
      title: 'Impôt sur le revenu',
      description:
          'Barème progressif par part de quotient familial (article 197 '
          'CGI) — voir la page Simulation → Fiscalité, onglet IR.',
      children: _bracketRows(
        count: _params.irRates.length,
        firstLabel: 'Jusqu\'à (€)',
        secondLabel: 'Taux (%)',
        unboundedLabel: 'Au-delà',
        firstValue: (i) => i < _params.irLimits.length ? _params.irLimits[i] : null,
        firstDefault: (i) => defaultIrLimits[i],
        onFirstChanged: (i, v) => _update(
          (p) => p.copyWith(irLimits: _replaced(p.irLimits, i, v)),
        ),
        secondValue: (i) => _params.irRates[i],
        secondDefault: (i) => defaultIrRates[i],
        onSecondChanged: (i, v) => _update(
          (p) => p.copyWith(irRates: _replaced(p.irRates, i, v)),
        ),
      ),
    );
  }

  Widget _buildIFISection() {
    return _TaxCard(
      title: 'IFI (impôt sur la fortune immobilière)',
      description:
          'Barème par tranches de patrimoine immobilier net (article 977 '
          'CGI) et seuil en-dessous duquel l\'IFI n\'est pas dû du tout.',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _EditableNumber(
            label: 'Seuil d\'imposition (€) — exonération totale en-dessous',
            value: _params.ifiSeuilImposition,
            defaultValue: defaultIfiSeuilImposition,
            onChanged: (v) =>
                _update((p) => p.copyWith(ifiSeuilImposition: v)),
          ),
        ),
        ..._bracketRows(
          count: _params.ifiRates.length,
          firstLabel: 'Jusqu\'à (€)',
          secondLabel: 'Taux (%)',
          unboundedLabel: 'Au-delà',
          firstValue: (i) =>
              i < _params.ifiLimits.length ? _params.ifiLimits[i] : null,
          firstDefault: (i) => defaultIfiLimits[i],
          onFirstChanged: (i, v) => _update(
            (p) => p.copyWith(ifiLimits: _replaced(p.ifiLimits, i, v)),
          ),
          secondValue: (i) => _params.ifiRates[i],
          secondDefault: (i) => defaultIfiRates[i],
          onSecondChanged: (i, v) => _update(
            (p) => p.copyWith(ifiRates: _replaced(p.ifiRates, i, v)),
          ),
        ),
      ],
    );
  }

  Widget _buildDemembrementSection() {
    final brackets = _params.demembrementBrackets;
    return _TaxCard(
      title: 'Démembrement (usufruit / nue-propriété)',
      description:
          'Barème fiscal de l\'usufruit selon l\'âge de l\'usufruitier '
          '(article 669 CGI) — voir la page Simulation → Transmission, '
          'onglet Démembrement.',
      children: _bracketRows(
        count: brackets.length,
        firstLabel: 'Jusqu\'à (ans)',
        secondLabel: 'Nue-propriété (%)',
        unboundedLabel: 'Au-delà',
        firstValue: (i) => brackets[i].maxAge?.toDouble(),
        firstDefault: (i) => defaultDemembrementBrackets[i].maxAge!.toDouble(),
        onFirstChanged: (i, v) => _update(
          (p) => p.copyWith(
            demembrementBrackets: _replaced(
              brackets,
              i,
              UsufruitBracket(v.round(), brackets[i].pctNue),
            ),
          ),
        ),
        secondValue: (i) => brackets[i].pctNue,
        secondDefault: (i) => defaultDemembrementBrackets[i].pctNue,
        onSecondChanged: (i, v) => _update(
          (p) => p.copyWith(
            demembrementBrackets: _replaced(
              brackets,
              i,
              UsufruitBracket(brackets[i].maxAge, v),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonationSection() {
    return _TaxCard(
      title: 'Donation et succession',
      description:
          'Barèmes des droits de mutation à titre gratuit (article 777 '
          'CGI) et abattements par lien de parenté — voir la page '
          'Simulation → Transmission, onglets Démembrement/Donation/'
          'Succession.',
      children: [
        const shadcn.Text('Abattements').medium(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _EditableNumber(
              label: 'Enfant (€)',
              value: _params.abattementEnfant,
              defaultValue: defaultAbattementEnfant,
              onChanged: (v) =>
                  _update((p) => p.copyWith(abattementEnfant: v)),
            ),
            _EditableNumber(
              label: 'Petit-enfant (€)',
              value: _params.abattementPetitEnfant,
              defaultValue: defaultAbattementPetitEnfant,
              onChanged: (v) =>
                  _update((p) => p.copyWith(abattementPetitEnfant: v)),
            ),
            _EditableNumber(
              label: 'Conjoint/PACS (€)',
              value: _params.abattementConjoint,
              defaultValue: defaultAbattementConjoint,
              onChanged: (v) =>
                  _update((p) => p.copyWith(abattementConjoint: v)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const shadcn.Text('Barème en ligne directe (parent/enfant)').medium(),
        const SizedBox(height: 8),
        ..._taxBracketRows(
          brackets: _params.directLineBrackets,
          defaults: defaultDirectLineBrackets,
          onChanged: (updated) =>
              _update((p) => p.copyWith(directLineBrackets: updated)),
        ),
        const SizedBox(height: 12),
        const shadcn.Text('Barème entre époux ou partenaires de PACS').medium(),
        const SizedBox(height: 8),
        ..._taxBracketRows(
          brackets: _params.spouseBrackets,
          defaults: defaultSpouseBrackets,
          onChanged: (updated) =>
              _update((p) => p.copyWith(spouseBrackets: updated)),
        ),
      ],
    );
  }

  Widget _buildPfuSection() {
    return _TaxCard(
      title: 'PFU (prélèvement forfaitaire unique)',
      description:
          '"Flat tax" sur les revenus de capitaux mobiliers et plus-values '
          'mobilières, décomposée en sa part IR et sa part prélèvements '
          'sociaux — l\'État peut réviser l\'une sans l\'autre (ex : PS '
          'passés de 15,5 % à 17,2 % en 2018, puis à 18,6 % début 2026, '
          'sans toucher au taux d\'IR). Valeurs de référence uniquement '
          'pour l\'instant : aucun simulateur de l\'app ne les utilise '
          'encore dans un calcul.',
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _EditableNumber(
              label: 'Part IR (%)',
              value: _params.pfuIrRate,
              defaultValue: defaultPfuIrRate,
              onChanged: (v) => _update((p) => p.copyWith(pfuIrRate: v)),
            ),
            _EditableNumber(
              label: 'Part prélèvements sociaux (%)',
              value: _params.pfuPsRate,
              defaultValue: defaultPfuPsRate,
              onChanged: (v) => _update((p) => p.copyWith(pfuPsRate: v)),
            ),
          ],
        ),
      ],
    );
  }

  /// Reconstruit une liste de barème [TaxBracket] en lignes seuil/taux —
  /// [TaxBracket.rate] est stocké en fraction (`0.05` pour 5 %, voir sa
  /// doc) alors que l'UI affiche/saisit toujours un pourcentage, d'où la
  /// conversion ×100/÷100 ici plutôt que dans [_bracketRows], générique et
  /// agnostique de cette convention de stockage.
  List<Widget> _taxBracketRows({
    required List<TaxBracket> brackets,
    required List<TaxBracket> defaults,
    required ValueChanged<List<TaxBracket>> onChanged,
  }) => _bracketRows(
    count: brackets.length,
    firstLabel: 'Jusqu\'à (€)',
    secondLabel: 'Taux (%)',
    unboundedLabel: 'Au-delà',
    firstValue: (i) =>
        brackets[i].upper.isFinite ? brackets[i].upper : null,
    firstDefault: (i) => defaults[i].upper,
    onFirstChanged: (i, v) => onChanged(
      _replaced(brackets, i, TaxBracket(v, brackets[i].rate)),
    ),
    secondValue: (i) => brackets[i].rate * 100,
    secondDefault: (i) => defaults[i].rate * 100,
    onSecondChanged: (i, v) => onChanged(
      _replaced(brackets, i, TaxBracket(brackets[i].upper, v / 100)),
    ),
  );
}

List<T> _replaced<T>(List<T> list, int index, T value) => [
  for (var i = 0; i < list.length; i++) i == index ? value : list[i],
];

/// Une ligne par tranche : un champ optionnel (seuil/âge, masqué et
/// remplacé par [unboundedLabel] pour la dernière tranche non plafonnée —
/// [firstValue] renvoie alors `null`) suivi d'un second champ toujours
/// présent (taux/pourcentage). Réutilisé par IR, IFI, démembrement et les
/// deux barèmes de donation/succession — les seules différences entre ces
/// 5 usages sont les libellés et les accesseurs, passés en paramètres.
List<Widget> _bracketRows({
  required int count,
  required String firstLabel,
  required String secondLabel,
  required String unboundedLabel,
  required double? Function(int i) firstValue,
  required double Function(int i) firstDefault,
  required void Function(int i, double v) onFirstChanged,
  required double Function(int i) secondValue,
  required double Function(int i) secondDefault,
  required void Function(int i, double v) onSecondChanged,
}) => [
  for (var i = 0; i < count; i++)
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (firstValue(i) != null)
            _EditableNumber(
              label: firstLabel,
              value: firstValue(i)!,
              defaultValue: firstDefault(i),
              onChanged: (v) => onFirstChanged(i, v),
            )
          else
            // Même largeur que `_EditableNumber` (150) : sinon la colonne
            // du taux se décale de 20px vers la gauche sur la ligne
            // "Au-delà" par rapport aux autres lignes, désalignant la
            // colonne des taux dans le tableau.
            SizedBox(
              width: 150,
              child: shadcn.Text(unboundedLabel).muted().small(),
            ),
          const SizedBox(width: 12),
          _EditableNumber(
            label: secondLabel,
            value: secondValue(i),
            defaultValue: secondDefault(i),
            onChanged: (v) => onSecondChanged(i, v),
          ),
        ],
      ),
    ),
];

class _TaxCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _TaxCard({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shadcn.Text(title).large().medium(),
            const SizedBox(height: 4),
            shadcn.Text(description).muted().xSmall(),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Un champ numérique unique avec son propre bouton de réinitialisation
/// (icône ↺, visible seulement quand [value] diffère de [defaultValue]) —
/// l'unité brique élémentaire réutilisée par toutes les sections de
/// [TaxParametersScreen] plutôt que d'écrire à la main chacun des ~70
/// champs de l'écran.
///
/// `key: ValueKey(value)` en usage (voir [_bracketRows]/les appels directs
/// ci-dessus) force un nouveau `TextField` (donc un nouveau contrôleur
/// interne, via `initialValue`) à chaque changement externe de [value] —
/// après un "Réinitialiser" par exemple — plutôt que de synchroniser un
/// contrôleur persistant, plus simple à raisonner correctement sur ~70
/// champs.
class _EditableNumber extends StatelessWidget {
  final String label;
  final double value;
  final double defaultValue;
  final ValueChanged<double> onChanged;

  const _EditableNumber({
    required this.label,
    required this.value,
    required this.defaultValue,
    required this.onChanged,
  });

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final isDefault = value == defaultValue;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.Text(label).muted().xSmall(),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey(value),
                  initialValue: _format(value),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (text) {
                    final parsed = parseDecimal(text);
                    if (parsed != null) onChanged(parsed);
                  },
                ),
              ),
              if (!isDefault) ...[
                const SizedBox(width: 4),
                Tooltip(
                  tooltip: (context) => const TooltipContainer(
                    child: shadcn.Text('Réinitialiser à la valeur légale'),
                  ),
                  child: IconButton.ghost(
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    onPressed: () => onChanged(defaultValue),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
