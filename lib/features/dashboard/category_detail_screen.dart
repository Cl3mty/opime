import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/date_format.dart';
import '../../core/ui/toggle_button_style.dart';
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/asset_table_header_cell.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/performance_amount.dart';
import '../../l10n/app_localizations.dart';
import '../investments/autres_photo_repository.dart';
import '../investments/bank_logo_avatar.dart';
import '../investments/bank_logo_repository.dart';
import '../investments/investments_models.dart';
import '../investments/widgets/transaction_widgets.dart'
    show ExcludedFromPatrimoineBadge;
import '../navigation/navigation_scope.dart';
import 'patrimoine_models.dart';
import 'widgets/allocation_blocks_view.dart';
import 'widgets/allocation_donut_view.dart';
import 'widgets/net_worth_chart.dart';
import 'widgets/patrimoine_chart_widgets.dart'
    show ChartLayer, CategoryMultiSelect, PeriodChangeRow, changePercentFor;

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Logos crypto (police `crypto_icons`, embarquée dans l'app — aucun appel
/// réseau) pour les tickers de [kKnownCryptoTickers] (`yahoo_finance_client
/// .dart`), reconstruits ici en `const` avec `fontPackage` explicite plutôt
/// que via `CryptoIcons.fromSymbol` : ce dernier omet `fontPackage` sur les
/// `IconData` qu'il renvoie, ce qui empêche Flutter de retrouver la police
/// "CryptocurrencyIcons" dans le bundle d'assets du package — le glyphe
/// retombe alors sur le caractère "non défini" (un gros point
/// d'interrogation), jamais sur le vrai logo. Un `IconData` doit de toute
/// façon être `const` pour rester compatible avec le tree-shaking des
/// polices d'icônes en build release (voir `@mustBeConst` sur `IconData
/// .codePoint`), donc une reconstruction dynamique à l'exécution n'aurait
/// pas été viable même corrigée. AVAX (dans [kKnownCryptoTickers]) n'a pas
/// de glyphe dans cette police — absent de cette table, retombe sur les
/// initiales comme n'importe quel ticker inconnu de la police.
const _cryptoIcons = <String, IconData>{
  'BTC': IconData(0xE045, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'ETH': IconData(0xE09E, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'USDT': IconData(0xE1A1, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'BNB': IconData(0xE03B, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'SOL': IconData(0xE174, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'XRP': IconData(0xE1CA, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'USDC': IconData(0xE1A0, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'ADA': IconData(0xE008, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'DOGE': IconData(0xE081, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'TRX': IconData(0xE198, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'DOT': IconData(0xE082, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'LINK': IconData(0xE0EC, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'MATIC': IconData(0xE0F6, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'LTC': IconData(0xE0F2, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'BCH': IconData(0xE02E, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'XLM': IconData(0xE1C0, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'ATOM': IconData(0xE022, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'ETC': IconData(0xE09D, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
  'UNI': IconData(0xE19D, fontFamily: 'CryptocurrencyIcons', fontPackage: 'crypto_icons'),
};

/// Page de détail générique d'une catégorie d'actif ou de passif : montant
/// + graphique sur la période sélectionnée, répartition par compte
/// ("Allocation", réutilise [AllocationBlocksView]) et tableau des
/// comptes de la catégorie — inspirée de la capture Finary "Crypto"
/// fournie. Réutilisée pour les 9 catégories `actifs_*`/`passifs_*` de
/// `nav_models.dart`.
class CategoryDetailScreen extends StatefulWidget {
  final PatrimoineCategory category;
  final AmountVisibilityController amountVisibility;

  /// Appelé quand une ligne du tableau des comptes est cliquée (`null` sur
  /// un écran sans drill-down, où les lignes ne sont alors pas cliquables) :
  /// permet à l'appelant (voir `RealCategoryDetailScreen`) d'ouvrir la vue
  /// de détail du compte/investissement réel correspondant.
  final ValueChanged<PatrimoineAccount>? onAccountTap;

  /// Contenu ajouté en bas de page, après le tableau des comptes — utilisé
  /// par `RealPassifDetailScreen` pour y insérer le bouton/formulaire
  /// d'ajout d'un nouveau passif sans dupliquer le reste de cette page.
  /// `null` (par défaut) n'ajoute rien.
  final Widget? trailingSection;

  /// Regroupement par compte (une ligne par compte, montants sommés) de la
  /// même catégorie que [category] — `null` masque le switch "Par compte /
  /// Par actif" de l'Allocation et n'affiche que [category.accounts] tel
  /// quel. Quand renseigné, [category.accounts] est utilisé comme vue "Par
  /// actif" (une ligne par investissement, ex : Google/Meta/Nvidia) et ce
  /// paramètre comme vue "Par compte" (ex : CTO/AV/PER/PEA) — voir
  /// `real_patrimoine_adapter.dart`.
  final List<PatrimoineAccount>? allocationByAccount;

  /// Regroupement par investissement réel (une ligne par ISIN — ou par
  /// ticker pour une crypto, qui n'a pas d'ISIN — fusionnée entre tous les
  /// comptes qui le détiennent, voir `real_patrimoine_adapter.dart`'s
  /// `buildRealCategoriesByInvestment`), pour la bascule "Par compte / Par
  /// investissement" du tableau des comptes (voir [_AccountsCard]) : un
  /// même titre/même crypto détenu dans plusieurs comptes (PEA et CTO, ou
  /// plusieurs wallets) n'y forme plus qu'une seule ligne à PRU/quantité/
  /// valeur fusionnés, au lieu d'une ligne par compte. `null` masque la
  /// bascule et garde le tableau tel quel (comportement par défaut, celui
  /// de [allocationByAccount] seul) — utilisé uniquement pour "Actions &
  /// Fonds" et "Crypto" (voir `RealCategoryDetailScreen`), les deux classes
  /// où détenir le même titre/la même crypto dans plusieurs comptes est un
  /// cas réel à fusionner.
  final List<PatrimoineAccount>? allocationByInvestment;

  /// Historique individuel de chaque ligne de [category.accounts] (clé :
  /// [PatrimoineAccount.id]) pour une période donnée, toutes sur une même
  /// grille de dates — `null` (comportement par défaut) utilise
  /// [historyForPeriod] à la place, sans sélecteur. Quand renseigné (passifs
  /// réels, voir `real_passifs_adapter.dart`'s `perLiabilityHistoryOnGrid`),
  /// un [CategoryMultiSelect] permet de choisir un/plusieurs/tous les prêts
  /// dont la somme forme la courbe affichée.
  final Map<String, List<NetWorthPoint>> Function(DashboardPeriod)?
  historyByLineIdForPeriod;

  /// Historique de la catégorie entière pour une période donnée — utilisé
  /// quand [historyByLineIdForPeriod] est `null`. `null` (les deux à la
  /// fois) affiche une courbe vide.
  final List<NetWorthPoint> Function(DashboardPeriod)? historyForPeriod;

  /// `false` masque l'avatar (initiales) devant chaque ligne du tableau des
  /// comptes et des investissements de l'accordéon — un prêt n'a pas
  /// d'initiales pertinentes, et les métaux précieux préfèrent des lignes
  /// sobres (initiales sans signification, ex : "L1" pour "Lingot 1Kg Or").
  final bool showAvatar;

  /// Titre du tableau des comptes de la catégorie — "Actifs" par défaut,
  /// "Passifs" pour les catégories de crédits/emprunts (voir
  /// `RealPassifDetailScreen`). `null` retombe sur le libellé localisé
  /// "Actifs"/"Assets" — un défaut littéral figé en français n'aurait pas
  /// suivi le changement de langue de l'app.
  final String? accountsCardTitle;

  /// `true` (défaut) affiche le "(±X %)" à côté du montant absolu sous le
  /// graphique (voir [PeriodChangeRow]). `false` pour `RealPassifDetailScreen`,
  /// dont la courbe projette toujours jusqu'au remboursement complet (0 €)
  /// quel que soit l'onglet de période choisi (voir sa doc de classe) — le
  /// pourcentage y vaudrait donc toujours -100 %, quelle que soit la
  /// période, une "performance" qui n'en est pas une.
  final bool showChangePercent;

  /// Menu "⋮" (Modifier/Supprimer) affiché au bout de chaque ligne de
  /// *compte* de l'accordéon (voir `_AccountAccordionTile`, uniquement
  /// quand [allocationByAccount] est renseigné) — `null` masque le menu
  /// entièrement. "Supprimer" reste désactivé si
  /// [PatrimoineAccount.canDelete] vaut `false`.
  final ValueChanged<PatrimoineAccount>? onAccountEdit;
  final Future<void> Function(PatrimoineAccount)? onAccountDelete;

  /// Remplace le menu "⋮" (Modifier/Supprimer) d'une ligne de *compte* : le
  /// clic sur la ligne (nom compris) ouvre directement sa page dédiée au
  /// lieu de (re)plier ses investissements — utilisé par
  /// `RealCategoryDetailScreen` pour toutes les classes d'actif sauf
  /// l'immobilier (voir `StockAccountScreen`, qui expose "Modifier"/
  /// "Supprimer" dans son propre menu, rendant le "⋮" du tableau
  /// redondant). Le dépli/repli reste possible via le chevron dédié en
  /// tête de ligne, jamais via le reste de la ligne. Quand renseigné,
  /// masque aussi le chevron des lignes d'investissement du second niveau
  /// de l'accordéon : cliquer une position n'y ouvre plus une page mais
  /// une popup, un chevron y serait trompeur. `null` (défaut) laisse le
  /// comportement "⋮" existant, ligne inerte au clic hors chevron/menu.
  final ValueChanged<PatrimoineAccount>? onAccountOpen;

  /// `true` (défaut) déplie tous les accordéons (banque et compte) — voir
  /// tout d'un coup d'œil sans avoir à cliquer plutôt que devoir déplier
  /// chaque ligne une à une. `false` conserve un état replié par défaut, si
  /// jamais un appelant en a besoin.
  final bool defaultExpanded;

  /// Chemin du vault — permet d'importer/remplacer les logos de banques
  /// (l'avatar d'une banque est cliquable, voir `BankLogoAvatar`). `null`
  /// rend l'avatar non cliquable.
  final String? vaultPath;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.amountVisibility,
    this.onAccountTap,
    this.trailingSection,
    this.allocationByAccount,
    this.allocationByInvestment,
    this.historyByLineIdForPeriod,
    this.historyForPeriod,
    this.showAvatar = true,
    this.accountsCardTitle,
    this.showChangePercent = true,
    this.onAccountEdit,
    this.onAccountDelete,
    this.onAccountOpen,
    this.defaultExpanded = true,
    this.vaultPath,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  int _periodIndex = 5;
  late Set<String> _selectedLineIds = {
    for (final a in widget.category.accounts)
      if (a.id != null) a.id!,
  };

  /// Repository des logos de banques — `null` sans [CategoryDetailScreen.vaultPath]
  /// renseigné, auquel cas aucun logo ne peut être importé.
  BankLogoRepository? get _logoRepo {
    final vaultPath = widget.vaultPath;
    return vaultPath == null ? null : BankLogoRepository(vaultPath);
  }

  /// Logos déjà importés, par nom de banque → chemin absolu de l'image
  /// (vide tant que rien n'est importé, ou en cours de lecture).
  Map<String, String> _bankLogos = {};

  /// Repository des photos d'objets "Autres" — `null` sans
  /// [CategoryDetailScreen.vaultPath] renseigné, auquel cas aucune photo ne
  /// peut être importée.
  AutresPhotoRepository? get _photoRepo {
    final vaultPath = widget.vaultPath;
    return vaultPath == null ? null : AutresPhotoRepository(vaultPath);
  }

  /// Photos déjà importées, par id d'investissement → chemin absolu de
  /// l'image (vide tant que rien n'est importé, ou en cours de lecture, ou
  /// hors catégorie "Autres" — seule concernée).
  Map<String, String> _autresPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadBankLogos();
    _loadAutresPhotos();
  }

  @override
  void didUpdateWidget(covariant CategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un rechargement des données (autre vault, compte ajouté/renommé...)
    // peut faire apparaître de nouvelles banques : on relit les logos.
    if (oldWidget.allocationByAccount != widget.allocationByAccount) {
      _loadBankLogos();
      _loadAutresPhotos();
    }
  }

  Future<void> _loadBankLogos() async {
    final repo = _logoRepo;
    if (repo == null) return;
    final byAccount = widget.allocationByAccount ?? const [];
    final banks = {for (final a in byAccount) a.bankName ?? a.name};
    final logos = <String, String>{};
    for (final bank in banks) {
      final path = await repo.logoPathFor(bank);
      if (path != null) logos[bank] = path;
    }
    if (!mounted) return;
    setState(() => _bankLogos = logos);
  }

  /// L'avatar d'une banque est cliquable : l'utilisateur choisit une image
  /// sur son disque, copiée dans le vault (voir `BankLogoRepository`).
  Future<void> _importBankLogo(String bankName) async {
    final repo = _logoRepo;
    if (repo == null) return;
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final path = await repo.importLogo(bankName, bytes, sourceName: file.name);
    if (path == null || !mounted) return;
    setState(() => _bankLogos = {..._bankLogos, bankName: path});
  }

  /// Tous les id d'investissement individuel apparaissant sur cette page,
  /// tous modes d'affichage confondus — une ligne de [widget.category.accounts]
  /// (vue "par actif") est déjà un investissement quand elle n'a pas de
  /// sous-investissements ; une ligne de [widget.allocationByAccount] (vue
  /// "par compte") ne l'est que via ses [PatrimoineAccount.investments].
  Set<String> _autresInvestmentIds() {
    final ids = <String>{};
    void collect(PatrimoineAccount a) {
      if (a.investments.isEmpty) {
        if (a.id != null) ids.add(a.id!);
      } else {
        for (final investment in a.investments) {
          if (investment.id != null) ids.add(investment.id!);
        }
      }
    }

    for (final a in widget.category.accounts) {
      collect(a);
    }
    for (final a in widget.allocationByAccount ?? const []) {
      collect(a);
    }
    return ids;
  }

  Future<void> _loadAutresPhotos() async {
    final repo = _photoRepo;
    if (repo == null || widget.category.id != AssetClass.autres.categoryId) {
      return;
    }
    final photos = <String, String>{};
    for (final id in _autresInvestmentIds()) {
      final path = await repo.photoPathFor(id);
      if (path != null) photos[id] = path;
    }
    if (!mounted) return;
    setState(() => _autresPhotos = photos);
  }

  /// L'avatar d'un objet "Autres" est cliquable : l'utilisateur choisit une
  /// image sur son disque, copiée dans le vault (voir
  /// `AutresPhotoRepository`) — même geste que [_importBankLogo].
  Future<void> _importAutresPhoto(PatrimoineAccount investment) async {
    final repo = _photoRepo;
    final id = investment.id;
    if (repo == null || id == null) return;
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final path = await repo.importPhoto(id, bytes, sourceName: file.name);
    if (path == null || !mounted) return;
    setState(() => _autresPhotos = {..._autresPhotos, id: path});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final hidden = widget.amountVisibility.hidden;
        final category = widget.category;
        final period = DashboardPeriod.values[_periodIndex];
        final historyByLineIdForPeriod = widget.historyByLineIdForPeriod;
        final points = historyByLineIdForPeriod == null
            ? widget.historyForPeriod?.call(period) ?? const <NetWorthPoint>[]
            : _combinedHistory(
                historyByLineIdForPeriod(period),
                _selectedLineIds,
              );
        final changePercent = widget.showChangePercent
            ? changePercentFor(points)
            : null;
        final absoluteChange = points.length < 2
            ? 0.0
            : points.last.value - points.first.value;
        final positive = absoluteChange >= 0;
        final color = positive ? _green : _red;

        final performanceCard = FrostedCard(
          expand: true,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Le montant réel d'aujourd'hui (category.montant),
                          // pas le dernier point de [points] : pour un
                          // passif, ce dernier point est le solde projeté à
                          // l'échéance (~0 €), pas le capital restant dû
                          // actuel (voir la doc de classe de
                          // [showChangePercent]) — les deux ne coïncident
                          // que côté actifs, où l'historique s'arrête
                          // toujours à aujourd'hui.
                          shadcn.Text(
                            displayEuros(category.montant, hidden),
                          ).x2Large().bold(),
                          const SizedBox(height: 4),
                          PeriodChangeRow(
                            absoluteChange: absoluteChange,
                            changePercent: changePercent,
                            hidden: hidden,
                            color: color,
                            icon: positive
                                ? LucideIcons.trendingUp
                                : LucideIcons.trendingDown,
                          ),
                        ],
                      ),
                    ),
                    if (historyByLineIdForPeriod != null) ...[
                      CategoryMultiSelect(
                        options: [
                          for (final a in category.accounts)
                            if (a.id != null)
                              ChartLayer(
                                id: a.id!,
                                label: a.name,
                                color: category.color,
                              ),
                        ],
                        selectedIds: _selectedLineIds,
                        onChanged: (ids) =>
                            setState(() => _selectedLineIds = ids),
                      ),
                      const SizedBox(width: 12),
                    ],
                    PeriodTabs(
                      labels: [for (final p in DashboardPeriod.values) p.label],
                      index: _periodIndex,
                      onChanged: (i) => setState(() => _periodIndex = i),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: NetWorthChart(
                    points: points,
                    formatValue: (v) => displayEuros(v, hidden),
                    axisLabelFormat: (v) => displayEurosCompact(v, hidden),
                    lineColor: category.color,
                    gridColor: Theme.of(context).colorScheme.border,
                    textColor: Theme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        );
        final allocationCard = _CategoryAllocationCard(
          category: category,
          byAccount: widget.allocationByAccount,
          byInvestment: widget.allocationByInvestment,
          hidden: hidden,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackHeader(category: category),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 800;
                  if (narrow) {
                    return Column(
                      children: [
                        SizedBox(height: 420, child: performanceCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 320, child: allocationCard),
                      ],
                    );
                  }
                  return SizedBox(
                    height: 420,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: performanceCard),
                        const SizedBox(width: 16),
                        Expanded(child: allocationCard),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _AccountsCard(
                category: category,
                byAccount: widget.allocationByAccount,
                byInvestment: widget.allocationByInvestment,
                hidden: hidden,
                onAccountTap: widget.onAccountTap,
                showAvatar: widget.showAvatar,
                title: widget.accountsCardTitle ?? l10n.dashboard_assets_title,
                onAccountEdit: widget.onAccountEdit,
                onAccountDelete: widget.onAccountDelete,
                onAccountOpen: widget.onAccountOpen,
                defaultExpanded: widget.defaultExpanded,
                bankLogos: _bankLogos,
                onImportLogo: widget.vaultPath == null ? null : _importBankLogo,
                autresPhotos: _autresPhotos,
                onImportPhoto: widget.vaultPath == null
                    ? null
                    : _importAutresPhoto,
                period: period,
              ),
              if (widget.trailingSection != null) ...[
                const SizedBox(height: 24),
                widget.trailingSection!,
              ],
            ],
          ),
        );
      },
    );
  }

  /// Somme, terme à terme (même grille de dates, voir
  /// `real_passifs_adapter.dart`'s `perLiabilityHistoryOnGrid`), les
  /// courbes des lignes actuellement sélectionnées dans le
  /// [CategoryMultiSelect] — la ligne vide (aucune sélection) retombe sur
  /// une courbe vide plutôt que de planter sur une division par zéro
  /// ailleurs dans l'écran.
  List<NetWorthPoint> _combinedHistory(
    Map<String, List<NetWorthPoint>> historyByLineId,
    Set<String> selectedIds,
  ) {
    final selected = [
      for (final id in selectedIds)
        if (historyByLineId[id] != null) historyByLineId[id]!,
    ];
    if (selected.isEmpty) return [];
    final pointCount = selected.first.length;
    return [
      for (var i = 0; i < pointCount; i++)
        NetWorthPoint(
          selected.first[i].date,
          selected.fold(0.0, (sum, series) => sum + series[i].value),
        ),
    ];
  }
}

class _BackHeader extends StatelessWidget {
  final PatrimoineCategory category;

  const _BackHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => NavigationScope.maybeOf(context)?.call('dashboard'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.chevronLeft, size: 20),
            const SizedBox(width: 4),
            shadcn.Text(category.label).x2Large().semiBold(),
          ],
        ),
      ),
    );
  }
}

enum _AllocationMode { parCompte, parActif }

enum _AllocationView { blocs, donut }

// Même correctif que le toggle Actifs/Passifs du Dashboard
// (`allocation_card.dart`) : la densité "compact" de shadcn_flutter rendait
// ces boutons illisibles/trop petits, mais la taille normale débordait sur
// les très grands écrans — on réduit donc de 5% seulement.
const _toggleButtonSize = ButtonSize(0.95);
const _toggleFontSize = 14.0 * 0.95;
const _toggleIconSize = 16.0 * 0.95;

/// Couleur de la [index]-ième part d'une allocation à plusieurs lignes
/// partageant la même couleur de base (une catégorie) — chaque ligne
/// suivante est un peu plus claire, pour les distinguer visuellement sans
/// leur inventer des couleurs arbitraires. Plafonné avant le blanc pur
/// (t = 1) : au-delà d'une dizaine de lignes, un dégradé non borné finit par
/// produire des couleurs blanches indiscernables du fond de la carte — une
/// ligne de plus n'apporterait alors plus aucune distinction visuelle. Le
/// dégradé continue de s'éclaircir ligne par ligne jusqu'à ce plafond, puis
/// les lignes suivantes gardent cette teinte la plus claire.
Color allocationSliceColor(Color baseColor, int index) {
  return Color.lerp(baseColor, Colors.white, (0.16 * index).clamp(0.0, 0.7)) ??
      baseColor;
}

/// Carte "Allocation" : répartition de la catégorie en blocs
/// ([AllocationBlocksView]) ou en anneau ([AllocationDonutView], mêmes 2
/// vues que la carte Allocation du Dashboard), soit par compte
/// (CTO/AV/PER/PEA...) soit par actif individuel (Google/Meta/Nvidia...)
/// quand [byAccount] est fourni — sans lui (Passifs), toujours
/// [category.accounts] sans switch de mode visible.
class _CategoryAllocationCard extends StatefulWidget {
  final PatrimoineCategory category;
  final List<PatrimoineAccount>? byAccount;

  /// Voir [CategoryDetailScreen.allocationByInvestment] — utilisé en vue
  /// "Par actif" à la place de [category.accounts] quand renseigné (Actions
  /// & Fonds, Crypto), pour qu'un même titre/même crypto détenu dans
  /// plusieurs comptes/wallets forme une seule part plutôt que d'être
  /// éclaté en plusieurs (régression signalée : BTC sur deux comptes créait
  /// deux parts distinctes du graphique, même en vue "Par actif").
  final List<PatrimoineAccount>? byInvestment;
  final bool hidden;

  const _CategoryAllocationCard({
    required this.category,
    this.byAccount,
    this.byInvestment,
    required this.hidden,
  });

  @override
  State<_CategoryAllocationCard> createState() => _CategoryAllocationCardState();
}

class _CategoryAllocationCardState extends State<_CategoryAllocationCard> {
  _AllocationMode _mode = _AllocationMode.parCompte;
  _AllocationView _view = _AllocationView.blocs;

  /// Regroupe les lignes de l'épargne par devise (le nom de chaque ligne
  /// est sa devise, ex : "EUR") et somme montants et plus-values des poches
  /// d'une même devise — les différentes poches EUR ne sont ainsi pas
  /// éclatées en plusieurs parts de l'allocation.
  List<PatrimoineAccount> _epargneLinesByCurrency(
    List<PatrimoineAccount> accounts,
  ) {
    final byCurrency = <String, List<PatrimoineAccount>>{};
    for (final account in accounts) {
      byCurrency.putIfAbsent(account.name, () => []).add(account);
    }
    return [for (final poches in byCurrency.values) _mergePoches(poches)];
  }

  PatrimoineAccount _mergePoches(List<PatrimoineAccount> poches) {
    // Cette page continue de tout comptabiliser, y compris une poche
    // exclue du patrimoine global (voir `PatrimoineAccount.
    // excludedFromPatrimoine`) — seuls les agrégats du Dashboard l'ignorent.
    final valeur = poches.fold(0.0, (sum, a) => sum + a.valeur);
    final plusValueAbs = poches.fold(0.0, (sum, a) => sum + (a.plusValueAbs ?? 0));
    final costBasis = valeur - plusValueAbs;
    return PatrimoineAccount(
      id: poches.first.name,
      name: poches.first.name,
      valeur: valeur,
      plusValueAbs: plusValueAbs,
      // `null` (pas `0`) sans coût d'acquisition — voir
      // `PatrimoineAccount.plusValuePercent`.
      plusValuePercent: costBasis == 0 ? null : plusValueAbs / costBasis * 100,
    );
  }

  /// Libellé d'une part de l'allocation. Pour l'épargne, un type de
  /// compte ouvrable plusieurs fois (assurance vie, contrat de
  /// capitalisation, "autre" — voir `epargneEnvelopeIsUniquePerBank`) peut
  /// exister en plusieurs exemplaires, même dans une même banque : sa
  /// description facultative est alors ajoutée au libellé pour distinguer
  /// les comptes entre eux.
  String _allocationLabel(
    PatrimoineAccount line,
    PatrimoineCategory category,
  ) {
    if (category.id != AssetClass.epargne.categoryId) return line.name;
    final envelope = AccountEnvelope.values.firstWhere(
      (e) => e.label == line.name,
      orElse: () => AccountEnvelope.autre,
    );
    final description = line.subtitle;
    if (description == null ||
        description.isEmpty ||
        epargneEnvelopeIsUniquePerBank(envelope)) {
      return line.name;
    }
    return '${line.name} · $description';
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final byAccount = widget.byAccount;
    // Vue "Par actif" de l'épargne : une même devise (EUR, USD...) détenue
    // dans plusieurs comptes (Livret A, LDDS, assurance vie...) ne forme
    // pas plusieurs catégories d'allocation distinctes — seul le
    // regroupement par devise compte, les poches d'une même devise sont
    // donc fusionnées (voir `_epargneLinesByCurrency`). Actions & Fonds et
    // Crypto ont le même besoin pour un titre/une crypto détenu dans
    // plusieurs comptes/wallets, déjà fusionné par [widget.byInvestment]
    // (voir sa doc) — priorité sur `category.accounts`, qui n'a jamais
    // cette fusion (une ligne par investissement PAR COMPTE).
    final lines = byAccount == null
        ? category.accounts
        : (_mode == _AllocationMode.parCompte
              ? byAccount
              : category.id == AssetClass.epargne.categoryId
              ? _epargneLinesByCurrency(category.accounts)
              : widget.byInvestment ?? category.accounts);
    // Cette allocation reste celle de la catégorie affichée sur sa
    // propre page : une ligne exclue du patrimoine global (voir
    // `PatrimoineAccount.excludedFromPatrimoine`) y garde sa part réelle,
    // seuls les agrégats du Dashboard l'ignorent.
    final montant = lines.fold(0.0, (sum, a) => sum + a.valeur);
    final slices = [
      for (var i = 0; i < lines.length; i++)
        AllocationSlice(
          id: lines[i].id ?? lines[i].name,
          label: _allocationLabel(lines[i], category),
          color: allocationSliceColor(category.color, i),
          percent: montant == 0 ? 0 : lines[i].valeur / montant * 100,
        ),
    ];

    return FrostedCard(
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 420;
                final title = shadcn.Text(
                  AppLocalizations.of(context).dashboard_allocation_title,
                ).semiBold().large();
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (byAccount != null)
                      ButtonGroup(
                        children: [
                          SelectedButton(
                            value: _mode == _AllocationMode.parCompte,
                            selectedStyle: const ButtonStyle.primary(
                              size: _toggleButtonSize,
                            ),
                            style: toggleUnselectedStyle(
                              context,
                              size: _toggleButtonSize,
                            ),
                            onChanged: (_) => setState(
                              () => _mode = _AllocationMode.parCompte,
                            ),
                            child: shadcn.Text(
                              'Par compte',
                              style: const TextStyle(fontSize: _toggleFontSize),
                            ),
                          ),
                          SelectedButton(
                            value: _mode == _AllocationMode.parActif,
                            selectedStyle: const ButtonStyle.primary(
                              size: _toggleButtonSize,
                            ),
                            style: toggleUnselectedStyle(
                              context,
                              size: _toggleButtonSize,
                            ),
                            onChanged: (_) => setState(
                              () => _mode = _AllocationMode.parActif,
                            ),
                            child: shadcn.Text(
                              'Par actif',
                              style: const TextStyle(fontSize: _toggleFontSize),
                            ),
                          ),
                        ],
                      ),
                    ButtonGroup(
                      children: [
                        SelectedButton(
                          value: _view == _AllocationView.blocs,
                          selectedStyle: const ButtonStyle.primary(
                            size: _toggleButtonSize,
                          ),
                          style: toggleUnselectedStyle(
                            context,
                            size: _toggleButtonSize,
                          ),
                          onChanged: (_) =>
                              setState(() => _view = _AllocationView.blocs),
                          child: const Icon(
                            LucideIcons.layoutGrid,
                            size: _toggleIconSize,
                          ),
                        ),
                        SelectedButton(
                          value: _view == _AllocationView.donut,
                          selectedStyle: const ButtonStyle.primary(
                            size: _toggleButtonSize,
                          ),
                          style: toggleUnselectedStyle(
                            context,
                            size: _toggleButtonSize,
                          ),
                          onChanged: (_) =>
                              setState(() => _view = _AllocationView.donut),
                          child: const Icon(
                            LucideIcons.chartPie,
                            size: _toggleIconSize,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), controls],
                  );
                }
                return Row(children: [title, const Spacer(), controls]);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _view == _AllocationView.blocs
                  ? AllocationBlocksView(slices: slices)
                  : AllocationDonutView(
                      slices: slices,
                      total: montant,
                      hidden: widget.hidden,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tableau "Actifs" de la page de détail d'une classe. Quand [byAccount]
/// est fourni, c'est un accordéon à deux niveaux : une ligne par compte
/// (montants sommés), dépliable pour révéler les investissements
/// individuels qui le composent ([PatrimoineAccount.investments], voir
/// `real_patrimoine_adapter.dart`). Sans lui (Passifs), reste la liste
/// plate de [PatrimoineCategory.accounts] d'origine.
/// Regroupement affiché par [_AccountsCard] — voir
/// [CategoryDetailScreen.allocationByInvestment].
enum _AccountsGroupingMode { parCompte, parInvestissement }

class _AccountsCard extends StatefulWidget {
  final PatrimoineCategory category;
  final List<PatrimoineAccount>? byAccount;

  /// Voir [CategoryDetailScreen.allocationByInvestment].
  final List<PatrimoineAccount>? byInvestment;
  final bool hidden;
  final ValueChanged<PatrimoineAccount>? onAccountTap;
  final bool showAvatar;
  final String title;
  final ValueChanged<PatrimoineAccount>? onAccountEdit;
  final Future<void> Function(PatrimoineAccount)? onAccountDelete;

  /// Voir [CategoryDetailScreen.onAccountOpen].
  final ValueChanged<PatrimoineAccount>? onAccountOpen;

  /// Voir [CategoryDetailScreen.defaultExpanded].
  final bool defaultExpanded;

  /// Logos importés par nom de banque → chemin absolu de l'image — voir
  /// `_CategoryDetailScreenState._bankLogos`.
  final Map<String, String> bankLogos;

  /// Importe/remplace le logo d'une banque (avatar cliquable de
  /// `_BankAccordionTile`), `null` quand aucun vault n'est disponible.
  final ValueChanged<String>? onImportLogo;

  /// Photos d'objets "Autres" importées par id d'investissement → chemin
  /// absolu de l'image — voir `_CategoryDetailScreenState._autresPhotos`.
  /// Vide (donc sans effet) pour toute catégorie autre qu'"Autres".
  final Map<String, String> autresPhotos;

  /// Importe/remplace la photo d'un objet "Autres" (avatar cliquable d'une
  /// ligne d'investissement individuel), `null` quand aucun vault n'est
  /// disponible.
  final ValueChanged<PatrimoineAccount>? onImportPhoto;

  /// Période affichée pour les colonnes "Évolution"/"+/- value" — voir
  /// `_AccountLine.period`.
  final DashboardPeriod period;

  const _AccountsCard({
    required this.category,
    this.byAccount,
    this.byInvestment,
    required this.hidden,
    this.onAccountTap,
    required this.showAvatar,
    required this.title,
    this.onAccountEdit,
    this.onAccountDelete,
    this.onAccountOpen,
    this.defaultExpanded = false,
    this.bankLogos = const {},
    this.onImportLogo,
    this.autresPhotos = const {},
    this.onImportPhoto,
    required this.period,
  });

  @override
  State<_AccountsCard> createState() => _AccountsCardState();
}

class _AccountsCardState extends State<_AccountsCard> {
  /// Regroupement affiché — n'a d'effet que quand [_AccountsCard.byInvestment]
  /// est renseigné (voir [CategoryDetailScreen.allocationByInvestment]),
  /// sinon la bascule elle-même reste masquée et ce champ n'est jamais lu.
  _AccountsGroupingMode _groupingMode = _AccountsGroupingMode.parCompte;

  /// Accordéons dont l'état diffère du défaut ([_AccountsCard.defaultExpanded])
  /// — un clic bascule l'état d'un id dedans ou hors de cet ensemble plutôt
  /// que de suivre directement "replié"/"déplié", pour permettre un défaut
  /// déplié (Actions & Fonds) comme replié (toutes les autres classes)
  /// avec le même état.
  final Set<String> _toggledIds = {};

  bool _isExpanded(String id) => widget.defaultExpanded
      ? !_toggledIds.contains(id)
      : _toggledIds.contains(id);

  void _toggleExpanded(String id) {
    setState(() {
      if (!_toggledIds.remove(id)) _toggledIds.add(id);
    });
  }

  /// La vue "par compte" regroupe les comptes par banque (la clé est
  /// [PatrimoineAccount.bankName], le nom du compte tenant lieu de banque à
  /// défaut) : un accordéon "banque → comptes → investissements". Un compte
  /// sans banque distincte (son nom fait banque) garde son accordéon simple
  /// actuel pour éviter un niveau d'imbrication redondant.
  List<Widget> _buildAccountAccordions(
    List<PatrimoineAccount> byAccount,
    bool showPru,
    bool showQuantityCours,
    bool showPnl,
  ) {
    final theme = Theme.of(context);
    final quantityAssetClass = assetClassForCategoryId(widget.category.id);
    final groups = <String, List<PatrimoineAccount>>{};
    for (final account in byAccount) {
      final key = account.bankName ?? account.name;
      groups.putIfAbsent(key, () => []).add(account);
    }
    final tiles = <Widget>[];
    for (final group in groups.entries) {
      tiles.add(Container(height: 1, color: theme.colorScheme.border));
      if (group.value.length == 1 && group.value.single.bankName == null) {
        final account = group.value.single;
        tiles.add(
          _AccountAccordionTile(
            account: account,
            hidden: widget.hidden,
            showAvatar: widget.showAvatar,
            showPru: showPru,
            showQuantityCours: showQuantityCours,
            showPnl: showPnl,
            quantityAssetClass: quantityAssetClass,
            expanded: _isExpanded(account.id ?? account.name),
            onToggleExpand: () => _toggleExpanded(account.id ?? account.name),
            onInvestmentTap: widget.onAccountTap,
            onEdit: widget.onAccountEdit,
            onDelete: widget.onAccountDelete,
            onAccountOpen: widget.onAccountOpen,
            autresPhotos: widget.autresPhotos,
            onImportPhoto: widget.onImportPhoto,
            period: widget.period,
          ),
        );
        continue;
      }
      // Banque avec logo : un accordéon banque qui révèle ses comptes, eux-
      // mêmes des accordéons vers leurs investissements. L'identité visuelle
      // porte sur la ligne banque seule : les lignes de compte (et leurs
      // investissements) n'affichent pas d'avatar sous une banque.
      final children = <Widget>[];
      for (final account in group.value) {
        children.add(Container(height: 1, color: theme.colorScheme.border));
        children.add(
          _AccountAccordionTile(
            account: account,
            hidden: widget.hidden,
            showAvatar: false,
            showPru: showPru,
            showQuantityCours: showQuantityCours,
            showPnl: showPnl,
            quantityAssetClass: quantityAssetClass,
            expanded: _isExpanded(account.id ?? account.name),
            onToggleExpand: () => _toggleExpanded(account.id ?? account.name),
            onInvestmentTap: widget.onAccountTap,
            onEdit: widget.onAccountEdit,
            onDelete: widget.onAccountDelete,
            onAccountOpen: widget.onAccountOpen,
            autresPhotos: widget.autresPhotos,
            onImportPhoto: widget.onImportPhoto,
            period: widget.period,
          ),
        );
      }
      tiles.add(
        _BankAccordionTile(
          bankName: group.key,
          accounts: group.value,
          logoPath: widget.bankLogos[group.key],
          onImportLogo: widget.onImportLogo,
          hidden: widget.hidden,
          showPru: showPru,
          showQuantityCours: showQuantityCours,
          showPnl: showPnl,
          expanded: _isExpanded('bank:$group.key'),
          onToggleExpand: () => _toggleExpanded('bank:$group.key'),
          period: widget.period,
          children: children,
        ),
      );
    }
    return tiles;
  }

  /// La vue "Par investissement" (voir
  /// [CategoryDetailScreen.allocationByInvestment]) : une ligne à plat par
  /// ISIN — pas de niveau banque, un même titre pouvant être détenu dans des
  /// banques différentes. Une ligne détenue dans un seul compte se comporte
  /// comme aujourd'hui (clic direct sur la position, pas de chevron) ; une
  /// ligne fusionnée entre plusieurs comptes (voir
  /// `real_patrimoine_adapter.dart`'s `_buildMergedInvestmentLeaf`, qui
  /// alimente [PatrimoineAccount.investments] dans ce cas) reste inerte au
  /// clic sur son titre — ambigu, quel compte ouvrir ? — et ne se déplie
  /// que via son chevron dédié, révélant une ligne par compte porteur,
  /// chacune cliquable individuellement.
  List<Widget> _buildInvestmentAccordions(
    List<PatrimoineAccount> byInvestment,
    bool showPru,
    bool showQuantityCours,
    bool showPnl,
  ) {
    final theme = Theme.of(context);
    final quantityAssetClass = assetClassForCategoryId(widget.category.id);
    final tiles = <Widget>[];
    for (final leaf in byInvestment) {
      final merged = leaf.investments.isNotEmpty;
      tiles.add(Container(height: 1, color: theme.colorScheme.border));
      tiles.add(
        _AccountAccordionTile(
          account: leaf,
          hidden: widget.hidden,
          showAvatar: widget.showAvatar,
          showPru: showPru,
          showQuantityCours: showQuantityCours,
          showPnl: showPnl,
          quantityAssetClass: quantityAssetClass,
          expanded: _isExpanded(leaf.id ?? leaf.name),
          onToggleExpand: () => _toggleExpanded(leaf.id ?? leaf.name),
          period: widget.period,
          onInvestmentTap: widget.onAccountTap,
          // Une ligne fusionnée n'a pas de compte unique à ouvrir : son
          // titre reste inerte (comme une ligne banque sans page propre),
          // seul son chevron la déplie. Une ligne à compte unique garde le
          // comportement direct habituel.
          onAccountOpen: merged ? null : widget.onAccountTap,
          autresPhotos: widget.autresPhotos,
          onImportPhoto: widget.onImportPhoto,
        ),
      );
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byInvestment = widget.byInvestment;
    final byAccount = widget.byAccount;
    final showPru = widget.category.showsPruColumn;
    final showQuantityCours = widget.category.showsQuantityColumn;
    final showPnl = widget.category.showsPnlColumn;
    return FrostedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = shadcn.Text(widget.title).semiBold().large();
                if (byInvestment == null) return title;
                final toggle = ButtonGroup(
                  children: [
                    SelectedButton(
                      value: _groupingMode == _AccountsGroupingMode.parCompte,
                      selectedStyle: const ButtonStyle.primary(
                        size: _toggleButtonSize,
                      ),
                      style: toggleUnselectedStyle(
                        context,
                        size: _toggleButtonSize,
                      ),
                      onChanged: (_) => setState(
                        () => _groupingMode = _AccountsGroupingMode.parCompte,
                      ),
                      child: shadcn.Text(
                        'Par compte',
                        style: const TextStyle(fontSize: _toggleFontSize),
                      ),
                    ),
                    SelectedButton(
                      value:
                          _groupingMode ==
                          _AccountsGroupingMode.parInvestissement,
                      selectedStyle: const ButtonStyle.primary(
                        size: _toggleButtonSize,
                      ),
                      style: toggleUnselectedStyle(
                        context,
                        size: _toggleButtonSize,
                      ),
                      onChanged: (_) => setState(
                        () => _groupingMode =
                            _AccountsGroupingMode.parInvestissement,
                      ),
                      child: shadcn.Text(
                        'Par investissement',
                        style: const TextStyle(fontSize: _toggleFontSize),
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), toggle],
                  );
                }
                return Row(children: [title, const Spacer(), toggle]);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: SizedBox()),
                if (showQuantityCours) ...[
                  const AssetTableHeaderCell('Quantité', width: _colWidth),
                  if (showPru)
                    const AssetTableHeaderCell('PRU', width: _colWidth),
                  const AssetTableHeaderCell('Cours', width: _colWidth),
                ],
                const AssetTableHeaderCell('Valeur', width: _colWidth),
                const AssetTableHeaderCell('Évolution', width: _colWidth),
                if (showPnl)
                  const AssetTableHeaderCell('+/- value', width: _colWidth),
                const SizedBox(width: _actionsWidth),
              ],
            ),
            if (byInvestment != null &&
                _groupingMode == _AccountsGroupingMode.parInvestissement) ...[
              ..._buildInvestmentAccordions(
                byInvestment,
                showPru,
                showQuantityCours,
                showPnl,
              ),
            ] else if (byAccount != null) ...[
              ..._buildAccountAccordions(
                byAccount,
                showPru,
                showQuantityCours,
                showPnl,
              ),
            ] else
              for (final account in widget.category.accounts) ...[
                Container(height: 1, color: theme.colorScheme.border),
                _AccountLine(
                  account: account,
                  hidden: widget.hidden,
                  showAvatar: widget.showAvatar,
                  showPru: showPru,
                  showQuantityCours: showQuantityCours,
                  showPnl: showPnl,
                  quantityAssetClass: assetClassForCategoryId(
                    widget.category.id,
                  ),
                  onTap: widget.onAccountTap == null
                      ? null
                      : () => widget.onAccountTap!(account),
                  avatarPhotoPath: account.id == null
                      ? null
                      : widget.autresPhotos[account.id],
                  onAvatarTap: widget.onImportPhoto == null
                      ? null
                      : () => widget.onImportPhoto!(account),
                  period: widget.period,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Ligne de compte dépliable de l'accordéon : le chevron dédié en tête de
/// ligne révèle ses investissements en dessous (voir [onToggleExpand]),
/// tandis que le reste de la ligne (nom compris) ouvre la page du compte
/// (voir [onAccountOpen]) — chaque investissement révélé est lui-même
/// cliquable via [onInvestmentTap] comme le reste des lignes de ce tableau.
class _AccountAccordionTile extends StatelessWidget {
  final PatrimoineAccount account;
  final bool hidden;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<PatrimoineAccount>? onInvestmentTap;
  final ValueChanged<PatrimoineAccount>? onEdit;
  final Future<void> Function(PatrimoineAccount)? onDelete;

  /// Voir [CategoryDetailScreen.onAccountOpen].
  final ValueChanged<PatrimoineAccount>? onAccountOpen;

  /// `false` masque aussi l'avatar (initiales) des lignes d'investissement
  /// du second niveau de l'accordéon — voir [CategoryDetailScreen.showAvatar].
  final bool showAvatar;

  /// Affiche la colonne PRU (Prix de Revient Unitaire) du tableau, cf.
  /// [PatrimoineCategory.showsPruColumn] — propagée aux deux niveaux de
  /// l'accordéon.
  final bool showPru;

  /// Affiche les colonnes Quantité et Cours du tableau, cf.
  /// [PatrimoineCategory.showsQuantityColumn] — propagée aux deux niveaux
  /// de l'accordéon.
  final bool showQuantityCours;

  /// Classe d'actif de la catégorie affichée, propagée aux lignes pour
  /// formater la quantité (entière pour les métaux précieux).
  final AssetClass? quantityAssetClass;

  /// Photos d'objets "Autres" par id d'investissement — voir
  /// `_AccountsCard.autresPhotos`, propagée uniquement aux lignes
  /// d'investissement (second niveau), jamais à la ligne de compte elle-même.
  final Map<String, String> autresPhotos;

  /// Voir `_AccountsCard.onImportPhoto`.
  final ValueChanged<PatrimoineAccount>? onImportPhoto;

  /// Voir `_AccountsCard.period`.
  final DashboardPeriod period;

  /// Affiche la colonne "+/- value" du tableau, cf.
  /// [PatrimoineCategory.showsPnlColumn] — propagée aux deux niveaux de
  /// l'accordéon, comme [showPru]/[showQuantityCours].
  final bool showPnl;

  const _AccountAccordionTile({
    required this.account,
    required this.hidden,
    required this.expanded,
    required this.onToggleExpand,
    this.onInvestmentTap,
    this.onEdit,
    this.onDelete,
    this.onAccountOpen,
    this.showAvatar = true,
    this.showPru = false,
    this.showQuantityCours = true,
    this.quantityAssetClass,
    this.autresPhotos = const {},
    this.onImportPhoto,
    required this.period,
    this.showPnl = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = account.investments.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: onAccountOpen != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          child: GestureDetector(
            // Cliquer la ligne (hors chevron/menu, voir plus bas) ouvre la
            // page du compte — le dépli/repli des investissements en
            // dessous ne se fait plus que via le chevron dédié. Sans page à
            // ouvrir (immobilier, voir [CategoryDetailScreen.onAccountOpen]),
            // la ligne reste inerte au clic, comme une ligne de banque.
            onTap: onAccountOpen == null ? null : () => onAccountOpen!(account),
            child: _AccountLine(
              account: account,
              hidden: hidden,
              showPru: showPru,
              showQuantityCours: showQuantityCours,
              showPnl: showPnl,
              quantityAssetClass: quantityAssetClass,
              period: period,
              leading: hasChildren
                  ? IconButton.ghost(
                      icon: AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                      onPressed: onToggleExpand,
                    )
                  : const SizedBox(width: 28),
              // Un chevron de navigation ferait double emploi avec le clic
              // sur la ligne elle-même désormais — seul le menu "⋮" (compte
              // sans page dédiée) garde sa place ici.
              trailing: onAccountOpen != null
                  ? null
                  : _AccountActionsMenu(
                      account: account,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
            ),
          ),
        ),
        if (hasChildren)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Column(
                      children: [
                        for (final investment in account.investments)
                          _AccountLine(
                            account: investment,
                            hidden: hidden,
                            showAvatar: showAvatar,
                            showPru: showPru,
                            showQuantityCours: showQuantityCours,
                            showPnl: showPnl,
                            quantityAssetClass: quantityAssetClass,
                            period: period,
                            // Une position ouvre une popup (voir
                            // `onAccountOpen`), pas une page : le chevron de
                            // navigation serait trompeur dans ce cas.
                            showChevron: onAccountOpen == null,
                            onTap: onInvestmentTap == null
                                ? null
                                : () => onInvestmentTap!(investment),
                            avatarPhotoPath: investment.id == null
                                ? null
                                : autresPhotos[investment.id],
                            onAvatarTap: onImportPhoto == null
                                ? null
                                : () => onImportPhoto!(investment),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// Accordéon d'une banque : l'avatar (logo importé ou initiales, cliquable
/// pour importer/remplacer l'image) + le nom de la banque et la somme de ses
/// comptes, dépliable — via le chevron dédié en tête de ligne uniquement,
/// une banque n'ayant pas de page propre à ouvrir — pour révéler ces
/// comptes, eux-mêmes des accordéons vers leurs investissements (voir
/// [_AccountAccordionTile], passé dans [children]).
class _BankAccordionTile extends StatelessWidget {
  final String bankName;
  final List<PatrimoineAccount> accounts;
  final String? logoPath;
  final ValueChanged<String>? onImportLogo;
  final bool hidden;
  final bool expanded;
  final VoidCallback onToggleExpand;

  /// Contenu déplié : les accordéons de comptes de cette banque (avec leurs
  /// séparateurs), construits par `_AccountsCardState` qui détient l'état
  /// d'expansion de chaque compte.
  final List<Widget> children;

  /// Affiche la colonne PRU (Prix de Revient Unitaire) du tableau — les
  /// cases Quantité/PRU/Cours restent vides sur une ligne banque (la somme
  /// n'y a pas de sens à l'unité).
  final bool showPru;

  /// Affiche les colonnes Quantité et Cours du tableau, cf.
  /// [PatrimoineCategory.showsQuantityColumn].
  final bool showQuantityCours;

  /// Voir `_AccountsCard.period`.
  final DashboardPeriod period;

  /// Affiche la colonne "+/- value" du sous-total, cf.
  /// [PatrimoineCategory.showsPnlColumn].
  final bool showPnl;

  const _BankAccordionTile({
    required this.bankName,
    required this.accounts,
    this.logoPath,
    this.onImportLogo,
    required this.hidden,
    required this.expanded,
    required this.onToggleExpand,
    required this.children,
    required this.period,
    this.showPru = false,
    this.showQuantityCours = true,
    this.showPnl = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sous-total réel de la banque — inclut un compte exclu du patrimoine
    // global (voir `PatrimoineAccount.excludedFromPatrimoine`), comme le
    // reste de cette page.
    final total = accounts.fold(0.0, (sum, a) => sum + a.valeur);
    // Évolution/PnL de la banque sur [period] : même astuce de soustraction
    // que `PatrimoineCategory.periodChangeFor`/`periodPnlFor` (agrégat des
    // lignes de compte, `total` moins la somme des deltas donne la
    // valorisation de départ) — un compte sans closure (aucun cas connu
    // aujourd'hui) est simplement ignoré de la somme.
    final changeResults = [
      for (final a in accounts) a.periodChangeFor?.call(period),
    ].whereType<({double euros, double? percent})>().toList();
    final changeEuros = changeResults.fold(0.0, (sum, r) => sum + r.euros);
    final changeStartValue = total - changeEuros;
    final changePercent = changeResults.isEmpty
        ? null
        : (changeStartValue != 0 ? changeEuros / changeStartValue * 100 : null);
    final pnlResults = [
      for (final a in accounts) a.periodPnlFor?.call(period),
    ].whereType<({double euros, double? percent})>().toList();
    final pnlEuros = pnlResults.fold(0.0, (sum, r) => sum + r.euros);
    final pnlNetInvested = total - pnlEuros;
    final pnlPercent = pnlResults.isEmpty
        ? null
        : (pnlNetInvested > 0 ? pnlEuros / pnlNetInvested * 100 : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Seul déclencheur du dépli/repli (voir la doc de classe) —
              // une banque n'a pas de page propre à ouvrir, le reste de la
              // ligne (nom, avatar mis à part) n'a donc aucune action au clic.
              IconButton.ghost(
                icon: AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                onPressed: onToggleExpand,
              ),
              BankLogoAvatar(
                bankName: bankName,
                logoPath: logoPath,
                onTap: onImportLogo == null
                    ? null
                    : () => onImportLogo!(bankName),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    shadcn.Text(bankName).medium().small(),
                    shadcn.Text(
                      accounts.length == 1
                          ? '1 compte'
                          : '${accounts.length} comptes',
                    ).muted().xSmall(),
                  ],
                ),
              ),
              // Cases Quantité/PRU/Cours : une banque n'a pas de sens à
              // l'unité, on n'affiche que Valeur et Évolution.
              if (showQuantityCours) ...[
                const SizedBox(width: _colWidth),
                if (showPru) const SizedBox(width: _colWidth),
                const SizedBox(width: _colWidth),
              ],
              SizedBox(
                width: _colWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: shadcn.Text(displayEuros(total, hidden)).small(),
                ),
              ),
              SizedBox(
                width: _colWidth,
                child: PerformanceAmount(
                  euros: changeResults.isEmpty ? null : changeEuros,
                  percent: changePercent,
                  hidden: hidden,
                ),
              ),
              if (showPnl)
                SizedBox(
                  width: _colWidth,
                  child: PerformanceAmount(
                    euros: pnlResults.isEmpty ? null : pnlEuros,
                    percent: pnlPercent,
                    hidden: hidden,
                  ),
                ),
              const SizedBox(width: _actionsWidth),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Column(children: children),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

const _colWidth = 92.0;

/// Largeur réservée pour la zone d'actions en bout de ligne (chevron de
/// navigation ou menu "⋮"), sur [_AccountLine] comme sur la ligne d'en-tête
/// du tableau (voir `_AccountsCardState.build`) — sans cette réservation
/// constante côté en-tête, la largeur variable de cette zone (rien, un
/// chevron, ou le menu "⋮", plus large) désalignait les colonnes de
/// valeurs des lignes selon ce qu'elles affichaient à leur bout.
const _actionsWidth = 32.0;

/// Avatar d'une ligne du tableau : la photo du produit ([PatrimoineAccount
/// .avatarImagePath], métaux précieux physiques) quand elle est disponible,
/// sinon les initiales — celles dérivées du nom, ou l'override éventuel
/// ([PatrimoineAccount.avatarInitials], ex : "ETC" pour un métal coté).
/// Un échec de lecture de l'image (fichier supprimé, corrompu...) retombe
/// silencieusement sur les initiales.
class _AccountAvatar extends StatelessWidget {
  final PatrimoineAccount account;

  /// Photo d'un objet "Autres" importée par l'utilisateur (voir
  /// `AutresPhotoRepository`), prioritaire sur [PatrimoineAccount
  /// .avatarImagePath] — cette dernière ne concerne que les métaux précieux
  /// physiques, qui n'ont jamais aussi de photo personnalisée.
  final String? overridePhotoPath;

  /// Rend l'avatar cliquable pour importer/remplacer [overridePhotoPath] —
  /// `null` (défaut) le laisse non cliquable.
  final VoidCallback? onTap;

  const _AccountAvatar({
    required this.account,
    this.overridePhotoPath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = overridePhotoPath ?? account.avatarImagePath;
    final Widget avatar;
    if (imagePath != null) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(imagePath),
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initials(context),
        ),
      );
    } else {
      avatar = _initials(context);
    }
    if (onTap == null) return avatar;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }

  /// Le vrai logo crypto (police `crypto_icons` embarquée dans l'app) quand
  /// [PatrimoineAccount.avatarCryptoSymbol] est renseigné et connu de
  /// [_cryptoIcons], sinon les initiales — voir la doc de ce champ.
  Widget _initials(BuildContext context) {
    final symbol = account.avatarCryptoSymbol;
    if (symbol != null) {
      final icon = _cryptoIcons[symbol.toUpperCase()];
      if (icon != null) {
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 16),
        );
      }
    }
    return Avatar(size: 28, initials: account.avatarInitials ?? account.initials);
  }
}

class _AccountLine extends StatelessWidget {
  final PatrimoineAccount account;
  final bool hidden;
  final VoidCallback? onTap;

  /// Remplace l'avatar par défaut — utilisé par [_AccountAccordionTile]
  /// pour afficher le chevron d'expansion à la place sur une ligne de
  /// compte, plutôt que d'ajouter une variante de widget séparée.
  final Widget? leading;

  /// `false` n'affiche ni [leading] ni l'avatar par défaut, juste
  /// l'espacement — un prêt n'a pas d'initiales pertinentes à afficher.
  final bool showAvatar;

  /// Widget affiché tout au bout de la ligne, après le chevron d'expansion
  /// éventuel — utilisé par [_AccountAccordionTile] pour son menu "⋮"
  /// (Modifier/Supprimer le compte). `null` n'ajoute rien.
  final Widget? trailing;

  /// Affiche la colonne PRU (Prix de Revient Unitaire) entre la quantité et
  /// le cours — cf. [PatrimoineCategory.showsPruColumn].
  final bool showPru;

  /// Affiche les colonnes Quantité et Cours — cf.
  /// [PatrimoineCategory.showsQuantityColumn] : un passif (prêt) n'a ni
  /// quantité ni cours de marché, contrairement à un actif.
  final bool showQuantityCours;

  /// Classe d'actif de la catégorie affichée : sert à formater la quantité
  /// (entière pour les pièces/lingots de métaux précieux). `null` pour une
  /// catégorie sans classe d'actif (passifs) : formatage par défaut.
  final AssetClass? quantityAssetClass;

  /// `false` masque le chevron par défaut affiché en bout de ligne quand
  /// [onTap] est renseigné sans [trailing] — voir
  /// [CategoryDetailScreen.onAccountOpen] : cliquer une position ouvre une
  /// popup, pas une page, le chevron y serait trompeur.
  final bool showChevron;

  /// Photo d'un objet "Autres" importée par l'utilisateur, remplaçant les
  /// initiales de l'avatar par défaut — voir `AutresPhotoAvatar`. `null`
  /// (défaut) pour toute ligne qui n'a pas de photo, ou hors catégorie
  /// "Autres".
  final String? avatarPhotoPath;

  /// Rend l'avatar cliquable pour importer/remplacer cette photo — `null`
  /// (défaut) le laisse non cliquable, comme pour toute autre catégorie.
  final VoidCallback? onAvatarTap;

  /// Période affichée pour les colonnes "Évolution"/"+/- value" — voir
  /// `_CategoryDetailScreenState`'s `_periodIndex`/`PeriodTabs`, déjà
  /// utilisé par le graphique du haut de la page, réutilisé ici pour les
  /// lignes du tableau.
  final DashboardPeriod period;

  /// Affiche la colonne "+/- value" — cf.
  /// [PatrimoineCategory.showsPnlColumn] : masquée entièrement pour un
  /// passif, plutôt que d'y afficher un « — » systématique (la performance
  /// hors flux n'a pas de sens pour une dette).
  final bool showPnl;

  const _AccountLine({
    required this.account,
    required this.hidden,
    this.trailing,
    this.onTap,
    this.leading,
    this.showAvatar = true,
    this.showPru = false,
    this.showQuantityCours = true,
    this.quantityAssetClass,
    this.showChevron = true,
    this.avatarPhotoPath,
    this.onAvatarTap,
    required this.period,
    this.showPnl = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = account.periodChangeFor?.call(period);
    final pnl = account.periodPnlFor?.call(period);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (showAvatar)
            leading ??
                _AccountAvatar(
                  account: account,
                  overridePhotoPath: avatarPhotoPath,
                  onTap: onAvatarTap,
                )
          else
            const SizedBox(width: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      // Une position en devise (cash tenu dans le compte)
                      // se distingue subtilement des titres — texte
                      // atténué plutôt qu'un badge, cohérent avec le reste
                      // de la ligne — voir [PatrimoineAccount.isCurrency].
                      child: account.isCurrency
                          ? shadcn.Text(account.name).muted().small()
                          : shadcn.Text(account.name).medium().small(),
                    ),
                    if (account.leverageBadge != null) ...[
                      const SizedBox(width: 6),
                      OutlineBadge(
                        child: shadcn.Text(account.leverageBadge!).xSmall(),
                      ),
                    ],
                    if (account.excludedFromPatrimoine) ...[
                      const SizedBox(width: 6),
                      const ExcludedFromPatrimoineBadge(),
                    ],
                  ],
                ),
                if (account.subtitle != null)
                  shadcn.Text(account.subtitle!).muted().xSmall(),
              ],
            ),
          ),
          if (showQuantityCours) ...[
            SizedBox(
              width: _colWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: shadcn.Text(
                  account.quantite != null
                      ? quantityAssetClass != null
                            ? formatQuantity(
                                account.quantite!,
                                quantityAssetClass!,
                              )
                            : account.quantite!.toStringAsFixed(2)
                      : '—',
                ).small(),
              ),
            ),
            if (showPru)
              SizedBox(
                width: _colWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: shadcn.Text(
                    account.pru != null
                        ? displayEuros(account.pru!, hidden)
                        : '—',
                  ).small(),
                ),
              ),
            SizedBox(
              width: _colWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: account.priceUnavailable == true && account.cours == null
                    // Un cours a été cherché et n'a pas été trouvé : on le
                    // signale plutôt que de ne laisser qu'un « — » silencieux
                    // (voir [PatrimoineAccount.priceUnavailable]).
                    ? Tooltip(
                        tooltip: (context) => TooltipContainer(
                          child: shadcn.Text(
                            'Cours introuvable sur Yahoo Finance pour cet '
                            'investissement.',
                          ),
                        ),
                        child: Icon(
                          LucideIcons.triangleAlert,
                          size: 14,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      )
                    : account.cours == null
                    ? shadcn.Text('—').small()
                    : _CoursCell(account: account, hidden: hidden),
              ),
            ),
          ],
          SizedBox(
            width: _colWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: shadcn.Text(displayEuros(account.valeur, hidden)).small(),
            ),
          ),
          SizedBox(
            width: _colWidth,
            child: PerformanceAmount(
              euros: change?.euros,
              percent: change?.percent,
              hidden: hidden,
            ),
          ),
          if (showPnl)
            SizedBox(
              width: _colWidth,
              child: PerformanceAmount(
                euros: pnl?.euros,
                percent: pnl?.percent,
                hidden: hidden,
              ),
            ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child:
                  trailing ??
                  (onTap != null && showChevron
                      ? Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: theme.colorScheme.mutedForeground,
                        )
                      : null),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}

/// Cellule "Cours" d'une ligne d'investissement : le prix, suivi d'un petit
/// badge quand [PatrimoineAccount.isPriceFresh] (cours récupéré aujourd'hui,
/// voir `Investment.isPriceFresh`) ou, à défaut, quand
/// [PatrimoineAccount.manualPriceAt] indique un cours estimé à la main —
/// même paire d'indicateurs que `ManualPriceBadge`/`FreshPriceBadge` sur la
/// popup de détail d'une position, mais sous forme d'icône compacte pour
/// tenir dans une cellule de tableau. Survoler la cellule affiche la date
/// correspondante.
class _CoursCell extends StatelessWidget {
  final PatrimoineAccount account;
  final bool hidden;

  const _CoursCell({required this.account, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final isManual = account.manualPriceAt != null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        shadcn.Text(displayEuros(account.cours!, hidden)).small(),
        if (account.isPriceFresh) ...[
          const SizedBox(width: 4),
          Icon(LucideIcons.badgeCheck, size: 12, color: Colors.green),
        ] else if (isManual) ...[
          const SizedBox(width: 4),
          Icon(
            LucideIcons.pencilLine,
            size: 12,
            color: Theme.of(context).colorScheme.mutedForeground,
          ),
        ],
      ],
    );
    final tooltipDate = account.lastPriceDate ?? account.manualPriceAt;
    if (tooltipDate == null) return content;
    return Tooltip(
      tooltip: (context) => TooltipContainer(
        child: shadcn.Text(
          account.isPriceFresh
              ? 'Cours à jour, récupéré le ${formatDateDdMmYyyy(tooltipDate)}.'
              : isManual
              ? 'Cours estimé à la main le ${formatDateDdMmYyyy(tooltipDate)}.'
              : 'Dernière mise à jour du cours : ${formatDateDdMmYyyy(tooltipDate)}.',
        ),
      ),
      child: content,
    );
  }
}

/// Menu "⋮" (Modifier/Supprimer le compte) d'une ligne de compte de
/// l'accordéon — même paire d'actions que `AccountDetailView`'s propre
/// menu (`account_detail_screen.dart`), exposée ici sans dépendre du
/// module Investissements (voir [CategoryDetailScreen.onAccountEdit]/
/// [CategoryDetailScreen.onAccountDelete]). Ne s'affiche que si au moins
/// une des deux actions est fournie.
class _AccountActionsMenu extends StatelessWidget {
  final PatrimoineAccount account;
  final ValueChanged<PatrimoineAccount>? onEdit;
  final Future<void> Function(PatrimoineAccount)? onDelete;

  const _AccountActionsMenu({
    required this.account,
    this.onEdit,
    this.onDelete,
  });

  void _openMenu(BuildContext context) {
    showDropdown(
      context: context,
      anchorAlignment: AlignmentDirectional.topEnd,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: DropdownMenu(
          children: [
            if (onEdit != null)
              MenuButton(
                leading: const Icon(LucideIcons.pencil, size: 14),
                child: const shadcn.Text('Modifier le compte'),
                onPressed: (_) => onEdit!(account),
              ),
            if (onDelete != null)
              MenuButton(
                enabled: account.canDelete,
                leading: const Icon(LucideIcons.trash2, size: 14),
                trailing: account.canDelete
                    ? null
                    : const shadcn.Text('Vide-le d\'abord').muted().xSmall(),
                child: const shadcn.Text('Supprimer le compte'),
                onPressed: (_) => onDelete!(account),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) => IconButton.ghost(
        icon: const Icon(LucideIcons.ellipsisVertical, size: 16),
        onPressed: () => _openMenu(context),
      ),
    );
  }
}
