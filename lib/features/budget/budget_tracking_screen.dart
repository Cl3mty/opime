import 'dart:math' as math;
import 'package:flutter/material.dart' show Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/money_format.dart';
import '../../core/privacy/amount_visibility_controller.dart';
import '../../core/ui/frosted_card.dart';
import 'budget_tracking_models.dart';
import 'budget_tracking_repository.dart';
import 'budget_categories_repository.dart';

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
  List<String> _categories = [];
  bool _loading = true;

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
    final categories = await _categoriesRepo.load();
    setState(() {
      _data = data;
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_data == null) return;
    await _repo.save(_data!);
  }

  void _update(BudgetTrackingMonth Function(BudgetTrackingMonth) updater) {
    if (_data == null) return;
    setState(() => _data = updater(_data!));
    _save();
  }

  Future<void> _createCategory(String name) async {
    final updated = await _categoriesRepo.addCategory(name);
    setState(() => _categories = updated);
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
    return AnimatedBuilder(
      animation: widget.amountVisibility,
      builder: (context, _) =>
          _buildContent(context, widget.amountVisibility.hidden),
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
                        categories: _categories,
                        onCreateCategory: _createCategory,
                        hidden: hidden,
                      );
                      final col3 = _CategoryCard(
                        title: 'DÉPENSES',
                        color: _red,
                        items: data.depenses,
                        idPrefix: 'depense',
                        onChanged: (items) =>
                            _update((d) => d.copyWith(depenses: items)),
                        categories: _categories,
                        onCreateCategory: _createCategory,
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

class _DistributionCard extends StatelessWidget {
  final BudgetTrackingMonth data;
  final Color accent;
  const _DistributionCard({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final slices = [
      ('Factures', data.totalFacturesRealite, _red),
      ('Dépenses', data.totalDepensesRealite, _red.withValues(alpha: 0.6)),
      ('Invest/Épargne', data.totalInvestRealite, accent),
      ('Projets', data.totalProjetsRealite, _red.withValues(alpha: 0.8)),
      ('Dettes', data.totalDettesRealite, _red.withValues(alpha: 0.4)),
    ].where((s) => s.$2 > 0).toList();
    final total = slices.fold<double>(0, (s, e) => s + e.$2);

    return Column(
      children: [
        shadcn.Text('Répartition').muted().small(),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: total <= 0
              ? Center(child: shadcn.Text('Aucune donnée').muted())
              : CustomPaint(
                  size: Size.infinite,
                  painter: _DonutPainter(slices: slices, total: total),
                ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final (label, value, color) in slices)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    shadcn.Text(
                      '$label ${(value / total * 100).round()}%',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
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
  _DonutPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 20.0;
    var startAngle = -math.pi / 2;

    for (final (_, value, color) in slices) {
      final sweep = (value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
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
      oldDelegate.slices != slices;
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
  final bool hidden;

  const _CategoryCard({
    required this.title,
    required this.color,
    required this.items,
    required this.idPrefix,
    required this.onChanged,
    this.categories,
    this.onCreateCategory,
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
                        child: shadcn.Text(
                          'Budget',
                          textAlign: TextAlign.end,
                        ).muted().small(),
                      ),
                      SizedBox(
                        width: 60,
                        child: shadcn.Text(
                          'Réalité',
                          textAlign: TextAlign.end,
                        ).muted().small(),
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
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      initialValue: item.budget == 0
                                          ? ''
                                          : item.budget.toStringAsFixed(0),
                                      style: const TextStyle(fontSize: 12),
                                      placeholder: shadcn.Text(
                                        'Budget',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.mutedForeground,
                                        ),
                                      ),
                                      textAlign: TextAlign.end,
                                      border: Border.all(
                                        color: Colors.transparent,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => onChanged([
                                        for (final i in items)
                                          if (i.id == item.id)
                                            i.copyWith(
                                              budget:
                                                  double.tryParse(
                                                    v.replaceAll(',', '.'),
                                                  ) ??
                                                  0,
                                            )
                                          else
                                            i,
                                      ]),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      initialValue: item.realite == 0
                                          ? ''
                                          : item.realite.toStringAsFixed(0),
                                      style: const TextStyle(fontSize: 12),
                                      placeholder: shadcn.Text(
                                        'Réalité',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.mutedForeground,
                                        ),
                                      ),
                                      textAlign: TextAlign.end,
                                      border: Border.all(
                                        color: Colors.transparent,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => onChanged([
                                        for (final i in items)
                                          if (i.id == item.id)
                                            i.copyWith(
                                              realite:
                                                  double.tryParse(
                                                    v.replaceAll(',', '.'),
                                                  ) ??
                                                  0,
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
                                child: TextField(
                                  initialValue: item.budget == 0
                                      ? ''
                                      : item.budget.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 12),
                                  placeholder: shadcn.Text(
                                    'Budget',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.mutedForeground,
                                    ),
                                  ),
                                  textAlign: TextAlign.end,
                                  border: Border.all(color: Colors.transparent),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => onChanged([
                                    for (final i in items)
                                      if (i.id == item.id)
                                        i.copyWith(
                                          budget:
                                              double.tryParse(
                                                v.replaceAll(',', '.'),
                                              ) ??
                                              0,
                                        )
                                      else
                                        i,
                                  ]),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  initialValue: item.realite == 0
                                      ? ''
                                      : item.realite.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 12),
                                  placeholder: shadcn.Text(
                                    'Réalité',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.mutedForeground,
                                    ),
                                  ),
                                  textAlign: TextAlign.end,
                                  border: Border.all(color: Colors.transparent),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => onChanged([
                                    for (final i in items)
                                      if (i.id == item.id)
                                        i.copyWith(
                                          realite:
                                              double.tryParse(
                                                v.replaceAll(',', '.'),
                                              ) ??
                                              0,
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
// Sélecteur de catégorie (chip + dropdown, création à la volée)
// ---------------------------------------------------------------------

class _CategoryChipPicker extends StatefulWidget {
  final String category;
  final List<String> categories;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onCreateNew;

  const _CategoryChipPicker({
    required this.category,
    required this.categories,
    required this.onSelected,
    required this.onCreateNew,
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
    showDropdown(
      context: anchorContext,
      anchorAlignment: AlignmentDirectional.bottomStart,
      alignment: AlignmentDirectional.topStart,
      offset: const Offset(0, 4),
      builder: (context) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
          child: DropdownMenu(
            children: [
              for (final cat in widget.categories)
                MenuButton(
                  trailing: cat == widget.category
                      ? const Icon(LucideIcons.check, size: 14)
                      : null,
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
