import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/expression_calculator.dart';
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/donut_hover.dart';
import '../../core/ui/frosted_card.dart';
import '../dashboard/widgets/allocation_hover_tooltip.dart';
import 'budget_tracking_models.dart';
import 'budget_tracking_repository.dart';
import 'budget_categories_repository.dart';
import 'budget_tracking_sankey.dart';

/// Annuler/Rétablir (⌘Z/⌘⇧Z sur macOS, Ctrl équivalent ailleurs) — propre
/// à cet écran (pas de la liste globale `AppShortcutAction`, réservée aux
/// raccourcis valables dans toute l'app) : n'a de sens que sur l'historique
/// d'édition du mois de Suivi actuellement affiché.
final _undoActivator = SingleActivator(
  LogicalKeyboardKey.keyZ,
  meta: Platform.isMacOS,
  control: !Platform.isMacOS,
);
final _redoActivator = SingleActivator(
  LogicalKeyboardKey.keyZ,
  meta: Platform.isMacOS,
  control: !Platform.isMacOS,
  shift: true,
);
final _undoShortcutLabel = Platform.isMacOS ? '⌘Z' : 'Ctrl+Z';
final _redoShortcutLabel = Platform.isMacOS ? '⌘⇧Z' : 'Ctrl+Maj+Z';

const _moisNoms = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

// Palette alignée sur Ventilation : vert = entrées, rouge = dépenses, or = investissements.
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

// Couleurs distinctes (pas de simples variantes d'opacité d'une même
// teinte, trop peu contrastées pour se distinguer à l'œil — voir
// [_DistributionCardState._slices]) pour Dépenses/Projets/Dettes, tout en
// restant dans la même famille "sorties d'argent" que Factures (_red) —
// mêmes couleurs déjà utilisées ailleurs dans l'app pour ces catégories
// (voir `real_passifs_adapter.dart`'s `_categoryMeta` pour Dettes, la
// palette d'avatars du Dashboard pour Projets).
const _orange = Color(0xFFF97316);
const _pink = Color(0xFFF472B6);
const _maroon = Color(0xFFDC2626);

class BudgetTrackingScreen extends StatefulWidget {
  final String vaultPath;
  final AmountVisibilityController amountVisibility;
  const BudgetTrackingScreen({
    super.key,
    required this.vaultPath,
    required this.amountVisibility,
  });

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  late final BudgetTrackingRepository _repo = BudgetTrackingRepository(
    widget.vaultPath,
  );
  late final BudgetCategoriesRepository _categoriesRepo =
      BudgetCategoriesRepository(widget.vaultPath);
  late int _year;
  late int _month;
  BudgetTrackingMonth? _data;

  /// Deux listes distinctes — une facture (loyer, abonnements...) et une
  /// dépense (courses, loisirs...) n'ont pas vocation à partager le même
  /// classement, voir [BudgetCategoryScope].
  List<String> _facturesCategories = [];
  List<String> _depensesCategories = [];
  bool _loading = true;

  /// Historique d'édition du mois affiché (Annuler/Rétablir, ⌘Z/⌘⇧Z) —
  /// un instantané complet de [_data] avant chaque modification, de sorte
  /// qu'annuler une suppression (une ligne, ou n'importe quel autre champ)
  /// la restitue telle quelle plutôt que de tenter de "réparer" la
  /// modification a posteriori. Vidé à chaque chargement de mois (voir
  /// [_load]) : annuler ne doit jamais faire ressurgir l'état d'un autre
  /// mois. Plafonné pour ne pas accumuler indéfiniment en mémoire pendant
  /// une longue session d'édition.
  final List<BudgetTrackingMonth> _undoStack = [];
  final List<BudgetTrackingMonth> _redoStack = [];
  static const _maxHistory = 50;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repo.load(_year, _month);
    final facturesCategories = await _categoriesRepo.load(
      BudgetCategoryScope.factures,
    );
    final depensesCategories = await _categoriesRepo.load(
      BudgetCategoryScope.depenses,
    );
    setState(() {
      _data = data;
      _facturesCategories = facturesCategories;
      _depensesCategories = depensesCategories;
      _loading = false;
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  Future<void> _save() async {
    if (_data == null) return;
    await _repo.save(_data!);
  }

  void _update(BudgetTrackingMonth Function(BudgetTrackingMonth) updater) {
    if (_data == null) return;
    _undoStack.add(_data!);
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
    setState(() => _data = updater(_data!));
    _save();
  }

  void _undo() {
    if (_undoStack.isEmpty || _data == null) return;
    _redoStack.add(_data!);
    final previous = _undoStack.removeLast();
    setState(() => _data = previous);
    _save();
  }

  void _redo() {
    if (_redoStack.isEmpty || _data == null) return;
    _undoStack.add(_data!);
    final next = _redoStack.removeLast();
    setState(() => _data = next);
    _save();
  }

  Future<void> _createCategory(BudgetCategoryScope scope, String name) async {
    final updated = await _categoriesRepo.addCategory(scope, name);
    setState(() {
      if (scope == BudgetCategoryScope.factures) {
        _facturesCategories = updated;
      } else {
        _depensesCategories = updated;
      }
    });
  }

  Future<void> _renameCategory(
    BudgetCategoryScope scope,
    String oldName,
    String newName,
  ) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final updated = await _categoriesRepo.renameCategory(
      scope,
      oldName,
      trimmed,
    );
    setState(() {
      if (scope == BudgetCategoryScope.factures) {
        _facturesCategories = updated;
      } else {
        _depensesCategories = updated;
      }
    });
    _relabelCategoryInCurrentMonth(scope, oldName, trimmed);
  }

  Future<void> _deleteCategory(BudgetCategoryScope scope, String name) async {
    final updated = await _categoriesRepo.removeCategory(scope, name);
    setState(() {
      if (scope == BudgetCategoryScope.factures) {
        _facturesCategories = updated;
      } else {
        _depensesCategories = updated;
      }
    });
    _relabelCategoryInCurrentMonth(scope, name, '');
  }

  /// Une catégorie renommée ou supprimée doit se refléter sur les lignes du
  /// mois affiché qui l'utilisaient encore, sinon leur puce resterait
  /// figée sur un nom absent de [_facturesCategories]/[_depensesCategories]
  /// et introuvable en rouvrant le picker. Passe par [_update] (donc
  /// Annuler/Rétablir + persistance) uniquement si une ligne est
  /// réellement concernée, pour ne pas polluer l'historique sinon.
  void _relabelCategoryInCurrentMonth(
    BudgetCategoryScope scope,
    String oldName,
    String newName,
  ) {
    final data = _data;
    if (data == null) return;
    final items = scope == BudgetCategoryScope.factures
        ? data.factures
        : data.depenses;
    if (!items.any((i) => i.category == oldName)) return;

    List<TrackingItem> relabel(List<TrackingItem> list) => [
      for (final i in list)
        if (i.category == oldName) i.copyWith(category: newName) else i,
    ];
    _update(
      (d) => scope == BudgetCategoryScope.factures
          ? d.copyWith(factures: relabel(d.factures))
          : d.copyWith(depenses: relabel(d.depenses)),
    );
  }

  void _changeMonth(int delta) {
    var newMonth = _month + delta;
    var newYear = _year;
    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }
    setState(() {
      _month = newMonth;
      _year = newYear;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // `CallbackShortcuts` n'intercepte les touches que si le nœud
    // actuellement focus est l'un de SES descendants (les évènements
    // remontent depuis le focus vers ses ancêtres) : le `Focus(autofocus)`
    // doit donc être À L'INTÉRIEUR, pas au-dessus — sinon c'est lui qui
    // tient le focus, et les touches remontent au-delà de
    // `CallbackShortcuts` sans jamais le traverser. `autofocus` reste
    // nécessaire malgré tout : sans aucun descendant focus (ex : avant le
    // premier clic dans une cellule), aucune touche n'aurait de nœud focus
    // depuis lequel remonter.
    return CallbackShortcuts(
      bindings: {
        _undoActivator: _undo,
        _redoActivator: _redo,
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: widget.amountVisibility,
          builder: (context, _) =>
              _buildContent(context, widget.amountVisibility.hidden),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool hidden) {
    final data = _data!;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: FrostedCard(
          expand: true,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -------------------- Annuler / Rétablir --------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        tooltip: (context) => TooltipContainer(
                          child: shadcn.Text('Annuler ($_undoShortcutLabel)'),
                        ),
                        child: IconButton.ghost(
                          icon: const Icon(LucideIcons.undo2, size: 18),
                          onPressed: _undoStack.isEmpty ? null : _undo,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        tooltip: (context) => TooltipContainer(
                          child: shadcn.Text('Rétablir ($_redoShortcutLabel)'),
                        ),
                        child: IconButton.ghost(
                          icon: const Icon(LucideIcons.redo2, size: 18),
                          onPressed: _redoStack.isEmpty ? null : _redo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // -------------------- Ligne du haut : titre + 3 visuels --------------------
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 900;
                      final children = [
                        _MonthTitleCard(
                          monthLabel: _moisNoms[_month - 1],
                          year: _year,
                          onPrev: () => _changeMonth(-1),
                          onNext: () => _changeMonth(1),
                        ),
                        _RemainingGaugeCard(
                          data: data,
                          accent: accent,
                          hidden: hidden,
                        ),
                        _ComparisonCard(data: data, accent: accent),
                        _DistributionCard(data: data, accent: accent),
                      ];
                      if (isNarrow) {
                        return Column(
                          children: [
                            for (final c in children)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: c,
                              ),
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < children.length; i++) ...[
                              Expanded(child: children[i]),
                              if (i != children.length - 1)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: VerticalDivider(width: 1),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  // -------------------- 4 colonnes de catégories --------------------
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 1100;
                      final col1 = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SummaryCard(
                            data: data,
                            accent: accent,
                            hidden: hidden,
                          ),
                          const SizedBox(height: 12),
                          _CategoryCard(
                            title: 'REVENUS',
                            color: _green,
                            items: data.revenues,
                            idPrefix: 'revenue',
                            onChanged: (items) =>
                                _update((d) => d.copyWith(revenues: items)),
                            hidden: hidden,
                          ),
                        ],
                      );
                      final col2 = _CategoryCard(
                        title: 'FACTURES',
                        color: _red,
                        items: data.factures,
                        idPrefix: 'facture',
                        onChanged: (items) =>
                            _update((d) => d.copyWith(factures: items)),
                        categories: _facturesCategories,
                        onCreateCategory: (name) =>
                            _createCategory(BudgetCategoryScope.factures, name),
                        onRenameCategory: (oldName, newName) => _renameCategory(
                          BudgetCategoryScope.factures,
                          oldName,
                          newName,
                        ),
                        onDeleteCategory: (name) =>
                            _deleteCategory(BudgetCategoryScope.factures, name),
                        hidden: hidden,
                      );
                      final col3 = _CategoryCard(
                        title: 'DÉPENSES',
                        color: _red,
                        items: data.depenses,
                        idPrefix: 'depense',
                        onChanged: (items) =>
                            _update((d) => d.copyWith(depenses: items)),
                        categories: _depensesCategories,
                        onCreateCategory: (name) =>
                            _createCategory(BudgetCategoryScope.depenses, name),
                        onRenameCategory: (oldName, newName) => _renameCategory(
                          BudgetCategoryScope.depenses,
                          oldName,
                          newName,
                        ),
                        onDeleteCategory: (name) =>
                            _deleteCategory(BudgetCategoryScope.depenses, name),
                        hidden: hidden,
                      );
                      final col4 = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CategoryCard(
                            title: 'INVEST / ÉPARGNE',
                            color: accent,
                            items: data.investEpargnes,
                            idPrefix: 'invest',
                            onChanged: (items) => _update(
                              (d) => d.copyWith(investEpargnes: items),
                            ),
                            hidden: hidden,
                          ),
                          const SizedBox(height: 12),
                          _CategoryCard(
                            title: 'PROJETS',
                            color: _red,
                            items: data.projets,
                            idPrefix: 'projet',
                            onChanged: (items) =>
                                _update((d) => d.copyWith(projets: items)),
                            hidden: hidden,
                          ),
                          const SizedBox(height: 12),
                          _CategoryCard(
                            title: 'DETTES',
                            color: _red,
                            items: data.dettes,
                            idPrefix: 'dette',
                            onChanged: (items) =>
                                _update((d) => d.copyWith(dettes: items)),
                            hidden: hidden,
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            col1,
                            const SizedBox(height: 12),
                            col2,
                            const SizedBox(height: 12),
                            col3,
                            const SizedBox(height: 12),
                            col4,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: col1),
                          const SizedBox(width: 12),
                          Expanded(child: col2),
                          const SizedBox(width: 12),
                          Expanded(child: col3),
                          const SizedBox(width: 12),
                          Expanded(child: col4),
                        ],
                      );
                    },
                  ),
                  // -------------------- Flux du mois (Sankey) --------------------
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  shadcn.Text('Flux du mois').muted().small(),
                  const SizedBox(height: 12),
                  BudgetTrackingSankeyChart(data: data, hidden: hidden),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Titre du mois avec navigation
// ---------------------------------------------------------------------

class _MonthTitleCard extends StatelessWidget {
  final String monthLabel;
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthTitleCard({
    required this.monthLabel,
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.chevronLeft, size: 16),
              onPressed: onPrev,
            ),
            shadcn.Text(monthLabel.toUpperCase()).large().bold(),
            IconButton.ghost(
              icon: const Icon(LucideIcons.chevronRight, size: 16),
              onPressed: onNext,
            ),
          ],
        ),
        shadcn.Text('$year').muted(),
        const SizedBox(height: 6),
        shadcn.Text('Tableau de suivi').muted().small(),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Jauge "Montant restant"
// ---------------------------------------------------------------------

class _RemainingGaugeCard extends StatelessWidget {
  final BudgetTrackingMonth data;
  final Color accent;
  final bool hidden;
  const _RemainingGaugeCard({
    required this.data,
    required this.accent,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final totalIn = data.totalRevenuesRealite;
    final fraction = totalIn > 0
        ? (data.restantRealite / totalIn).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        shadcn.Text('Montant restant').muted().small(),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _GaugePainter(
              fraction: fraction,
              color: accent,
              trackColor: Theme.of(context).colorScheme.muted,
            ),
            child: Center(
              child: shadcn.Text(
                displayEuros(data.restantRealite, hidden),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;
  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

// ---------------------------------------------------------------------
// Comparaison Budget vs Réalité
// ---------------------------------------------------------------------

class _ComparisonCard extends StatelessWidget {
  final BudgetTrackingMonth data;
  final Color accent;
  const _ComparisonCard({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Factures', data.totalFacturesBudget, data.totalFacturesRealite, _red),
      ('Dépenses', data.totalDepensesBudget, data.totalDepensesRealite, _red),
      (
        'Invest/Épargne',
        data.totalInvestBudget,
        data.totalInvestRealite,
        accent,
      ),
      ('Projets', data.totalProjetsBudget, data.totalProjetsRealite, _red),
      ('Dettes', data.totalDettesBudget, data.totalDettesRealite, _red),
    ].where((r) => r.$2 > 0 || r.$3 > 0).toList();

    return Column(
      children: [
        shadcn.Text('Sommaire des entrées/sorties').muted().small(),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: rows.isEmpty
              ? Center(child: shadcn.Text('Aucune donnée').muted())
              : CustomPaint(
                  size: Size.infinite,
                  painter: _ComparisonPainter(rows: rows),
                ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              shadcn.Text('Budget', style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 14),
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              shadcn.Text('Réalité', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ],
    );
  }
}

class _ComparisonPainter extends CustomPainter {
  final List<(String, double, double, Color)> rows;
  _ComparisonPainter({required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = rows
        .map((r) => math.max(r.$2, r.$3))
        .reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return;

    final rowHeight = size.height / rows.length;
    const labelWidth = 90.0;
    final barAreaWidth = size.width - labelWidth;

    for (var i = 0; i < rows.length; i++) {
      final (label, budget, realite, color) = rows[i];
      final rowTop = i * rowHeight;

      final tpLabel = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 6);
      tpLabel.paint(
        canvas,
        Offset(0, rowTop + rowHeight / 2 - tpLabel.height / 2),
      );

      final barHeight = (rowHeight * 0.32).clamp(4.0, 10.0);
      final budgetWidth = (budget / maxValue) * barAreaWidth;
      final realiteWidth = (realite / maxValue) * barAreaWidth;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            labelWidth,
            rowTop + rowHeight * 0.18,
            budgetWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: 0.35),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            labelWidth,
            rowTop + rowHeight * 0.55,
            realiteWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ComparisonPainter oldDelegate) =>
      oldDelegate.rows != rows;
}

// ---------------------------------------------------------------------
// Répartition (donut)
// ---------------------------------------------------------------------

/// Répartition Réalité entre Factures/Dépenses/Invest·Épargne/Projets/
/// Dettes — même transformation au survol qu'`AllocationDonutView` (carte
/// Allocation du Dashboard) : la section survolée s'isole (les autres
/// s'estompent, dans l'anneau comme dans la légende) et un libellé + son
/// pourcentage exact s'affichent près du curseur ([AllocationHoverTooltip],
/// widget déjà partagé avec le Dashboard). Reste volontairement un
/// [CustomPainter] compact et propre à cet écran plutôt qu'un remplacement
/// direct par [AllocationDonutView] : cette dernière repose sur des
/// `LayoutBuilder` dont la taille intrinsèque n'est pas définie, incompatible
/// avec l'`IntrinsicHeight` de la rangée des 4 cartes du haut de page.
class _DistributionCard extends StatefulWidget {
  final BudgetTrackingMonth data;
  final Color accent;
  const _DistributionCard({required this.data, required this.accent});

  @override
  State<_DistributionCard> createState() => _DistributionCardState();
}

class _DistributionCardState extends State<_DistributionCard> {
  int? _hoveredIndex;
  Offset? _pointer;

  List<(String, double, Color)> get _slices =>
      [
        ('Factures', widget.data.totalFacturesRealite, _red),
        ('Dépenses', widget.data.totalDepensesRealite, _orange),
        ('Invest/Épargne', widget.data.totalInvestRealite, widget.accent),
        ('Projets', widget.data.totalProjetsRealite, _pink),
        ('Dettes', widget.data.totalDettesRealite, _maroon),
      ].where((s) => s.$2 > 0).toList();

  void _updateHover(Offset localPosition, Size size, double total) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final hoveredIndex = hitTestDonutSlice(
      point: localPosition,
      center: center,
      radius: radius,
      strokeWidth: 20.0,
      values: [for (final s in _slices) s.$2],
    );
    setState(() {
      _hoveredIndex = hoveredIndex;
      _pointer = localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final slices = _slices;
    final total = slices.fold<double>(0, (s, e) => s + e.$2);
    final hoveredIndex = _hoveredIndex;
    final hovered = hoveredIndex != null && hoveredIndex < slices.length
        ? slices[hoveredIndex]
        : null;

    return Column(
      children: [
        shadcn.Text('Répartition').muted().small(),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: total <= 0
              ? Center(child: shadcn.Text('Aucune donnée').muted())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return MouseRegion(
                      // `onEnter` en plus de `onHover` : voir
                      // `allocation_donut_view.dart`'s équivalent — sans
                      // lui, l'anneau apparu sous une souris déjà immobile
                      // (ouverture de la page, changement de mois...)
                      // n'affichait aucun surlignage tant que la souris ne
                      // bougeait pas encore un peu après y être entrée.
                      onEnter: (event) =>
                          _updateHover(event.localPosition, size, total),
                      onHover: (event) =>
                          _updateHover(event.localPosition, size, total),
                      onExit: (_) => setState(() {
                        _hoveredIndex = null;
                        _pointer = null;
                      }),
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: size,
                            painter: _DonutPainter(
                              slices: slices,
                              total: total,
                              hoveredIndex: hoveredIndex,
                            ),
                          ),
                          if (hovered != null && _pointer != null)
                            Positioned(
                              left: (_pointer!.dx - 70).clamp(
                                0.0,
                                math.max(0.0, size.width - 140),
                              ),
                              top: (_pointer!.dy + 8).clamp(
                                0.0,
                                math.max(0.0, size.height - 36),
                              ),
                              child: IgnorePointer(
                                child: AllocationHoverTooltip(
                                  label: hovered.$1,
                                  percent: hovered.$2 / total * 100,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              for (var i = 0; i < slices.length; i++)
                AnimatedOpacity(
                  // Zéro délai : même raisonnement que
                  // `AllocationDonutView`'s légende — l'arc du donut
                  // (`_DonutPainter`) est repeint instantanément au survol,
                  // la légende ne doit pas traîner derrière.
                  duration: Duration.zero,
                  opacity: hoveredIndex != null && hoveredIndex != i
                      ? 0.35
                      : 1.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: slices[i].$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      shadcn.Text(
                        '${slices[i].$1} '
                        '${(slices[i].$2 / total * 100).round()}%',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(String, double, Color)> slices;
  final double total;
  final int? hoveredIndex;
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 20.0;
    final dimmed = hoveredIndex != null;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < slices.length; i++) {
      final (_, value, color) = slices[i];
      final sweep = (value / total) * 2 * math.pi;
      final isHovered = i == hoveredIndex;
      final paint = Paint()
        ..color = color.withValues(alpha: dimmed && !isHovered ? 0.3 : 1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = dimmed && !isHovered ? strokeWidth * 0.95 : strokeWidth;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.hoveredIndex != hoveredIndex;
}

// ---------------------------------------------------------------------
// Résumé (Entrées/Sorties d'argent) — sans Report
// ---------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final BudgetTrackingMonth data;
  final Color accent;
  final bool hidden;
  const _SummaryCard({
    required this.data,
    required this.accent,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.border),
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Theme.of(context).radiusMd),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Center(
              child: shadcn.Text(
                "ENTRÉES / SORTIES D'ARGENT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Expanded(flex: 2, child: SizedBox.shrink()),
                      Expanded(
                        child: shadcn.Text(
                          'Budget',
                          textAlign: TextAlign.end,
                        ).muted().small(),
                      ),
                      Expanded(
                        child: shadcn.Text(
                          'Réalité',
                          textAlign: TextAlign.end,
                        ).muted().small(),
                      ),
                    ],
                  ),
                ),
                _summaryRow(
                  '+ Revenus',
                  data.totalRevenuesBudget,
                  data.totalRevenuesRealite,
                ),
                _summaryRow(
                  '- Factures',
                  -data.totalFacturesBudget,
                  -data.totalFacturesRealite,
                ),
                _summaryRow(
                  '- Dépenses',
                  -data.totalDepensesBudget,
                  -data.totalDepensesRealite,
                ),
                _summaryRow(
                  '- Invest/Épargne',
                  -data.totalInvestBudget,
                  -data.totalInvestRealite,
                ),
                _summaryRow(
                  '- Projets',
                  -data.totalProjetsBudget,
                  -data.totalProjetsRealite,
                ),
                _summaryRow(
                  '- Dettes',
                  -data.totalDettesBudget,
                  -data.totalDettesRealite,
                ),
                const Divider(),
                _summaryRow(
                  'RESTANT',
                  data.restantBudget,
                  data.restantRealite,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double budget,
    double realite, {
    bool bold = false,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(flex: 2, child: shadcn.Text(label, style: style)),
          Expanded(
            child: shadcn.Text(
              displayEuros(budget, hidden),
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
          Expanded(
            child: shadcn.Text(
              displayEuros(realite, hidden),
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Carte de catégorie éditable (avec catégorisation optionnelle par item)
// ---------------------------------------------------------------------

class _CategoryCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<TrackingItem> items;
  final String idPrefix;
  final ValueChanged<List<TrackingItem>> onChanged;
  final List<String>? categories;
  final ValueChanged<String>? onCreateCategory;
  final void Function(String oldName, String newName)? onRenameCategory;
  final ValueChanged<String>? onDeleteCategory;
  final bool hidden;

  const _CategoryCard({
    required this.title,
    required this.color,
    required this.items,
    required this.idPrefix,
    required this.onChanged,
    this.categories,
    this.onCreateCategory,
    this.onRenameCategory,
    this.onDeleteCategory,
    required this.hidden,
  });

  bool get _showCategoryPicker =>
      categories != null && onCreateCategory != null;

  double get _totalBudget => items.fold(0, (s, i) => s + i.budget);
  double get _totalRealite => items.fold(0, (s, i) => s + i.realite);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.border),
        borderRadius: BorderRadius.circular(Theme.of(context).radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Theme.of(context).radiusMd),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: shadcn.Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 60,
                        child: Tooltip(
                          tooltip: (context) => const TooltipContainer(
                            child: SizedBox(
                              width: 220,
                              child: shadcn.Text(
                                'Vous pouvez saisir un calcul directement '
                                'dans la cellule (ex : 45+12,5).',
                              ),
                            ),
                          ),
                          child: shadcn.Text(
                            'Budget',
                            textAlign: TextAlign.end,
                          ).muted().small(),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Tooltip(
                          tooltip: (context) => const TooltipContainer(
                            child: SizedBox(
                              width: 220,
                              child: shadcn.Text(
                                'Vous pouvez saisir un calcul directement '
                                'dans la cellule (ex : 45+12,5).',
                              ),
                            ),
                          ),
                          child: shadcn.Text(
                            'Réalité',
                            textAlign: TextAlign.end,
                          ).muted().small(),
                        ),
                      ),
                      const SizedBox(
                        width: 32,
                      ), // réserve l'espace du bouton supprimer des lignes
                    ],
                  ),
                ),
                for (final item in items)
                  Padding(
                    key: ValueKey(item.id),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _showCategoryPicker
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      initialValue: item.name,
                                      style: const TextStyle(fontSize: 12),
                                      placeholder: shadcn.Text(
                                        'Nom',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.mutedForeground,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: Colors.transparent,
                                      ),
                                      onChanged: (v) => onChanged([
                                        for (final i in items)
                                          if (i.id == item.id)
                                            i.copyWith(name: v)
                                          else
                                            i,
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _CategoryChipPicker(
                                    category: item.category,
                                    categories: categories!,
                                    onSelected: (cat) => onChanged([
                                      for (final i in items)
                                        if (i.id == item.id)
                                          i.copyWith(category: cat)
                                        else
                                          i,
                                    ]),
                                    onCreateNew: (name) {
                                      onCreateCategory!(name);
                                      onChanged([
                                        for (final i in items)
                                          if (i.id == item.id)
                                            i.copyWith(category: name)
                                          else
                                            i,
                                      ]);
                                    },
                                    onRenameCategory: onRenameCategory,
                                    onDeleteCategory: onDeleteCategory,
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: 60,
                                    child: _AmountCell(
                                      value: item.budget,
                                      formula: item.budgetFormula,
                                      placeholder: 'Budget',
                                      onChanged: (v, formula) => onChanged([
                                        for (final i in items)
                                          if (i.id == item.id)
                                            i.copyWith(
                                              budget: v,
                                              budgetFormula: () => formula,
                                            )
                                          else
                                            i,
                                      ]),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: _AmountCell(
                                      value: item.realite,
                                      formula: item.realiteFormula,
                                      placeholder: 'Réalité',
                                      onChanged: (v, formula) => onChanged([
                                        for (final i in items)
                                          if (i.id == item.id)
                                            i.copyWith(
                                              realite: v,
                                              realiteFormula: () => formula,
                                            )
                                          else
                                            i,
                                      ]),
                                    ),
                                  ),
                                  IconButton.ghost(
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      size: 14,
                                    ),
                                    onPressed: () => onChanged(
                                      items
                                          .where((i) => i.id != item.id)
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  initialValue: item.name,
                                  style: const TextStyle(fontSize: 12),
                                  placeholder: shadcn.Text(
                                    'Nom',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.mutedForeground,
                                    ),
                                  ),
                                  border: Border.all(color: Colors.transparent),
                                  onChanged: (v) => onChanged([
                                    for (final i in items)
                                      if (i.id == item.id)
                                        i.copyWith(name: v)
                                      else
                                        i,
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 60,
                                child: _AmountCell(
                                  value: item.budget,
                                  formula: item.budgetFormula,
                                  placeholder: 'Budget',
                                  onChanged: (v, formula) => onChanged([
                                    for (final i in items)
                                      if (i.id == item.id)
                                        i.copyWith(
                                          budget: v,
                                          budgetFormula: () => formula,
                                        )
                                      else
                                        i,
                                  ]),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: _AmountCell(
                                  value: item.realite,
                                  formula: item.realiteFormula,
                                  placeholder: 'Réalité',
                                  onChanged: (v, formula) => onChanged([
                                    for (final i in items)
                                      if (i.id == item.id)
                                        i.copyWith(
                                          realite: v,
                                          realiteFormula: () => formula,
                                        )
                                      else
                                        i,
                                  ]),
                                ),
                              ),
                              IconButton.ghost(
                                icon: const Icon(LucideIcons.trash2, size: 14),
                                onPressed: () => onChanged(
                                  items.where((i) => i.id != item.id).toList(),
                                ),
                              ),
                            ],
                          ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: GestureDetector(
                    onTap: () => onChanged([
                      ...items,
                      TrackingItem(
                        id: generateTrackingItemId(idPrefix),
                        name: '',
                        budget: 0,
                        realite: 0,
                      ),
                    ]),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.plus,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        shadcn.Text(
                          'Ajouter',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ).small(),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: shadcn.Text(
                          'TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: shadcn.Text(
                          displayEuros(_totalBudget, hidden),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: shadcn.Text(
                          displayEuros(_totalRealite, hidden),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Cellule Budget/Réalité : accepte un calcul basique
// ---------------------------------------------------------------------

/// Champ Budget/Réalité d'une ligne de [_CategoryCard] : accepte un simple
/// nombre comme avant, mais aussi une expression arithmétique basique
/// (+, -, *, /, parenthèses — voir `evaluateAmountExpression` dans
/// `core/expression_calculator.dart`), pour calculer un montant directement
/// dans la cellule (ex : "45+12,5" pour deux courses dans le mois) sans
/// avoir à faire le calcul de tête ou dans une app séparée. Le résultat est
/// propagé à [onChanged] dès que l'expression tapée devient valide (une
/// expression encore incomplète, ex. "45+", n'écrase pas la dernière valeur
/// valide). Comme un tableur : au repos (champ non sélectionné), le texte
/// affiché est le résultat calculé, avec 2 décimales ; en cliquant dans la
/// cellule, elle réaffiche la dernière expression tapée (ex : "45+12,5")
/// plutôt que ce résultat seul, pour permettre de la corriger sans devoir
/// tout retaper — y compris après avoir quitté puis rouvert la page ou le
/// mois, l'expression étant persistée avec le résultat (voir
/// [TrackingItem.budgetFormula]/[TrackingItem.realiteFormula]), pas juste
/// gardée en mémoire pour la session en cours.
class _AmountCell extends StatefulWidget {
  final double value;

  /// Dernière expression tapée, persistée (ex : "40+30" — voir
  /// [TrackingItem.budgetFormula]/[TrackingItem.realiteFormula]). `null`
  /// si la cellule n'a jamais été éditée via une expression (valeur
  /// importée, saisie d'un simple nombre historique...). Contrairement à
  /// une valeur transitoire en mémoire, cette formule survit à la
  /// destruction du widget — en quittant puis en revenant sur ce mois,
  /// la cellule peut donc encore montrer sa décomposition au lieu du
  /// seul résultat.
  final String? formula;

  final String placeholder;

  /// Appelé avec le résultat calculé et l'expression brute qui y a mené
  /// (`null` si la cellule a été vidée) — les deux doivent être persistés
  /// ensemble par l'appelant pour que [formula] reste disponible après un
  /// remontage du widget.
  final void Function(double value, String? formula) onChanged;

  const _AmountCell({
    required this.value,
    this.formula,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  State<_AmountCell> createState() => _AmountCellState();
}

class _AmountCellState extends State<_AmountCell> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  late final FocusNode _focusNode = FocusNode()
    ..addListener(_handleFocusChange);

  /// Dernier texte tapé dans le champ (ex : "40+30"), réaffiché quand la
  /// cellule reprend le focus — voir [_handleFocusChange]. Amorcé depuis
  /// [_AmountCell.formula] (persisté) plutôt que toujours `null`, pour que
  /// la décomposition du calcul reste consultable même après un remontage
  /// du widget (ex : en quittant puis en revenant sur ce mois) — pas
  /// seulement pendant la session en cours.
  late String? _lastTypedText = widget.formula;

  /// `true` pendant qu'on modifie [_controller.text] nous-mêmes
  /// (programmatique, pas une frappe de l'utilisateur) — voir
  /// [_handleFocusChange]. `TextField` (shadcn_flutter) écoute directement
  /// le controller et redéclenche [_handleChanged] pour TOUT changement de
  /// texte, y compris ceux qu'on déclenche nous-mêmes (ex : remplacer
  /// "40+10" par son résultat "50,00" au moment de quitter la cellule) —
  /// sans ce garde-fou, ce remplacement se rappelle lui-même comme une
  /// nouvelle saisie ("50,00", un nombre valide) et écrase silencieusement
  /// la vraie formule qu'on venait tout juste de persister correctement à
  /// la ligne suivante.
  bool _isProgrammaticTextChange = false;

  String _format(double value) => value == 0 ? '' : value.toStringAsFixed(2);

  void _handleChanged(String text) {
    if (_isProgrammaticTextChange) return;
    final evaluated = evaluateAmountExpression(text);
    if (evaluated != null) widget.onChanged(evaluated, text);
  }

  void _setControllerText(String text, {TextSelection? selection}) {
    _isProgrammaticTextChange = true;
    _controller.text = text;
    if (selection != null) _controller.selection = selection;
    _isProgrammaticTextChange = false;
  }

  /// À la prise de focus, réaffiche la dernière expression tapée (ex :
  /// "40+30") plutôt que le résultat calculé affiché au repos ("70,00") —
  /// comme un tableur qui montre la formule d'une cellule sélectionnée et
  /// son résultat une fois qu'on la quitte, pour pouvoir la corriger sans
  /// devoir la retaper entièrement. Le texte est sélectionné en entier,
  /// prêt à être remplacé d'un coup si besoin.
  ///
  /// À la perte du focus, l'expression tapée est réévaluée une dernière
  /// fois et le texte affiché est remplacé par le résultat — un champ vidé
  /// retombe sur 0 (comme avant), mais une expression laissée incomplète
  /// (ex. l'utilisateur clique ailleurs juste après avoir tapé "45+") ne
  /// doit pas effacer la dernière valeur valide déjà propagée par
  /// [_handleChanged] : elle retombe alors sur [widget.value] plutôt que 0.
  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      final lastTyped = _lastTypedText;
      if (lastTyped != null) {
        _setControllerText(
          lastTyped,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: lastTyped.length,
          ),
        );
      }
      return;
    }
    final text = _controller.text.trim();
    final evaluated = text.isEmpty
        ? 0.0
        : evaluateAmountExpression(text) ?? widget.value;
    _lastTypedText = text.isEmpty ? null : text;
    _setControllerText(_format(evaluated));
    if (evaluated != widget.value || _lastTypedText != widget.formula) {
      widget.onChanged(evaluated, _lastTypedText);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: const TextStyle(fontSize: 12),
      placeholder: shadcn.Text(
        widget.placeholder,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
      textAlign: TextAlign.end,
      border: Border.all(color: Colors.transparent),
      onChanged: _handleChanged,
    );
  }
}

// ---------------------------------------------------------------------
// Sélecteur de catégorie (chip + dropdown, création à la volée)
// ---------------------------------------------------------------------

class _CategoryChipPicker extends StatefulWidget {
  final String category;
  final List<String> categories;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onCreateNew;

  /// Édition/suppression d'une catégorie de la liste elle-même (pas de la
  /// sélection de CETTE ligne) — absents (`null`) pour les colonnes sans
  /// picker de catégorie ; toujours fournis ensemble par l'écran pour
  /// Factures/Dépenses, voir `_CategoryCard.onRenameCategory`.
  final void Function(String oldName, String newName)? onRenameCategory;
  final ValueChanged<String>? onDeleteCategory;

  const _CategoryChipPicker({
    required this.category,
    required this.categories,
    required this.onSelected,
    required this.onCreateNew,
    this.onRenameCategory,
    this.onDeleteCategory,
  });

  @override
  State<_CategoryChipPicker> createState() => _CategoryChipPickerState();
}

class _CategoryChipPickerState extends State<_CategoryChipPicker> {
  final _newCategoryController = TextEditingController();

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  void _openPicker(BuildContext anchorContext) {
    // Éditer ou supprimer une catégorie change la liste que ce picker a
    // capturée (`widget.categories`) : plutôt que de tenter de refléter ce
    // changement en direct dans le menu encore ouvert, on referme
    // simplement le menu après l'action — le rouvrir montre la liste à
    // jour. `editingCategory` ne gère que le repli local du champ de
    // renommage, avant confirmation.
    String? editingCategory;
    final editController = TextEditingController();
    late final OverlayCompleter completer;

    completer = showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.bottomStart,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            void confirmRename(String cat) {
              final newName = editController.text.trim();
              setPickerState(() => editingCategory = null);
              if (newName.isEmpty || newName == cat) return;
              widget.onRenameCategory?.call(cat, newName);
              // Différée à la frame suivante : retirer ce menu de l'arbre
              // pendant le traitement du clic (sous le curseur à cet
              // instant) fait planter `MouseTracker`
              // ("!_debugDuringDeviceUpdate").
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => completer.remove(),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
              child: DropdownMenu(
                children: [
                  for (final cat in widget.categories)
                    editingCategory == cat
                        ? MenuButton(
                            onPressed: (ctx) {},
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: editController,
                                    autofocus: true,
                                    border: Border.all(
                                      color: Colors.transparent,
                                    ),
                                    onSubmitted: (_) => confirmRename(cat),
                                  ),
                                ),
                                IconButton.ghost(
                                  icon: const Icon(
                                    LucideIcons.check,
                                    size: 14,
                                  ),
                                  onPressed: () => confirmRename(cat),
                                ),
                              ],
                            ),
                          )
                        : MenuButton(
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (cat == widget.category)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(LucideIcons.check, size: 14),
                                  ),
                                if (widget.onRenameCategory != null)
                                  IconButton.ghost(
                                    icon: const Icon(
                                      LucideIcons.pencil,
                                      size: 12,
                                    ),
                                    onPressed: () => setPickerState(() {
                                      editingCategory = cat;
                                      editController.text = cat;
                                    }),
                                  ),
                                if (widget.onDeleteCategory != null)
                                  IconButton.ghost(
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      size: 12,
                                    ),
                                    onPressed: () {
                                      widget.onDeleteCategory!(cat);
                                      // Voir le commentaire équivalent dans
                                      // confirmRename ci-dessus.
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                            (_) => completer.remove(),
                                          );
                                    },
                                  ),
                              ],
                            ),
                            child: shadcn.Text(cat),
                            onPressed: (ctx) => widget.onSelected(cat),
                          ),
                  const MenuDivider(),
                  MenuButton(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newCategoryController,
                            placeholder: const shadcn.Text('Nouvelle catégorie'),
                            border: Border.all(color: Colors.transparent),
                          ),
                        ),
                        IconButton.ghost(
                          icon: const Icon(LucideIcons.plus, size: 14),
                          onPressed: () {
                            final name = _newCategoryController.text.trim();
                            if (name.isEmpty) return;
                            widget.onCreateNew(name);
                            _newCategoryController.clear();
                          },
                        ),
                      ],
                    ),
                    onPressed: (ctx) {},
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnContext) => GestureDetector(
        onTap: () => _openPicker(btnContext),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              shadcn.Text(
                widget.category.isEmpty ? 'Catégorie' : widget.category,
              ).small(),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronDown, size: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
