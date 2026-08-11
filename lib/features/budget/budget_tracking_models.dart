import 'dart:math';

String generateTrackingItemId(String prefix) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  final suffix = List.generate(
    8,
    (_) => chars[rand.nextInt(chars.length)],
  ).join();
  return '${prefix}_$suffix';
}

class TrackingItem {
  final String id;
  final String name;
  final double budget;
  final double realite;
  final bool checked;
  final String category; // vide = non catégorisé

  TrackingItem({
    String? id,
    required this.name,
    required this.budget,
    required this.realite,
    this.checked = false,
    this.category = '',
  }) : id = id ?? generateTrackingItemId('item');

  TrackingItem copyWith({
    String? name,
    double? budget,
    double? realite,
    bool? checked,
    String? category,
  }) => TrackingItem(
    id: id,
    name: name ?? this.name,
    budget: budget ?? this.budget,
    realite: realite ?? this.realite,
    checked: checked ?? this.checked,
    category: category ?? this.category,
  );

  factory TrackingItem.fromJson(Map<String, dynamic> json) => TrackingItem(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    budget: (json['budget'] as num?)?.toDouble() ?? 0,
    realite: (json['realite'] as num?)?.toDouble() ?? 0,
    checked: json['checked'] as bool? ?? false,
    category: json['category'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'budget': budget,
    'realite': realite,
    'checked': checked,
    'category': category,
  };
}

class BudgetTrackingMonth {
  final int month; // 1-12
  final int year;
  final List<TrackingItem> revenues;
  final List<TrackingItem> factures;
  final List<TrackingItem> depenses;
  final List<TrackingItem> investEpargnes;
  final List<TrackingItem> projets;
  final List<TrackingItem> dettes;

  BudgetTrackingMonth({
    required this.month,
    required this.year,
    required this.revenues,
    required this.factures,
    required this.depenses,
    required this.investEpargnes,
    required this.projets,
    required this.dettes,
  });

  factory BudgetTrackingMonth.empty(int month, int year) => BudgetTrackingMonth(
    month: month,
    year: year,
    revenues: [],
    factures: [],
    depenses: [],
    investEpargnes: [],
    projets: [],
    dettes: [],
  );

  BudgetTrackingMonth copyWith({
    List<TrackingItem>? revenues,
    List<TrackingItem>? factures,
    List<TrackingItem>? depenses,
    List<TrackingItem>? investEpargnes,
    List<TrackingItem>? projets,
    List<TrackingItem>? dettes,
  }) => BudgetTrackingMonth(
    month: month,
    year: year,
    revenues: revenues ?? this.revenues,
    factures: factures ?? this.factures,
    depenses: depenses ?? this.depenses,
    investEpargnes: investEpargnes ?? this.investEpargnes,
    projets: projets ?? this.projets,
    dettes: dettes ?? this.dettes,
  );

  static double _sum(
    List<TrackingItem> items,
    double Function(TrackingItem) f,
  ) => items.fold(0, (s, i) => s + f(i));

  double get totalRevenuesBudget => _sum(revenues, (i) => i.budget);
  double get totalRevenuesRealite => _sum(revenues, (i) => i.realite);
  double get totalFacturesBudget => _sum(factures, (i) => i.budget);
  double get totalFacturesRealite => _sum(factures, (i) => i.realite);
  double get totalDepensesBudget => _sum(depenses, (i) => i.budget);
  double get totalDepensesRealite => _sum(depenses, (i) => i.realite);
  double get totalInvestBudget => _sum(investEpargnes, (i) => i.budget);
  double get totalInvestRealite => _sum(investEpargnes, (i) => i.realite);
  double get totalProjetsBudget => _sum(projets, (i) => i.budget);
  double get totalProjetsRealite => _sum(projets, (i) => i.realite);
  double get totalDettesBudget => _sum(dettes, (i) => i.budget);
  double get totalDettesRealite => _sum(dettes, (i) => i.realite);

  double get restantBudget =>
      totalRevenuesBudget -
      totalFacturesBudget -
      totalDepensesBudget -
      totalInvestBudget -
      totalProjetsBudget -
      totalDettesBudget;

  double get restantRealite =>
      totalRevenuesRealite -
      totalFacturesRealite -
      totalDepensesRealite -
      totalInvestRealite -
      totalProjetsRealite -
      totalDettesRealite;

  factory BudgetTrackingMonth.fromJson(Map<String, dynamic> json) =>
      BudgetTrackingMonth(
        month: json['month'] as int,
        year: json['year'] as int,
        revenues: _listFromJson(json['revenues']),
        factures: _listFromJson(json['factures']),
        depenses: _listFromJson(json['depenses']),
        investEpargnes: _listFromJson(json['investEpargnes']),
        projets: _listFromJson(json['projets']),
        dettes: _listFromJson(json['dettes']),
      );

  static List<TrackingItem> _listFromJson(dynamic raw) => (raw as List? ?? [])
      .map((e) => TrackingItem.fromJson(e as Map<String, dynamic>))
      .toList();

  Map<String, dynamic> toJson() => {
    'month': month,
    'year': year,
    'revenues': revenues.map((i) => i.toJson()).toList(),
    'factures': factures.map((i) => i.toJson()).toList(),
    'depenses': depenses.map((i) => i.toJson()).toList(),
    'investEpargnes': investEpargnes.map((i) => i.toJson()).toList(),
    'projets': projets.map((i) => i.toJson()).toList(),
    'dettes': dettes.map((i) => i.toJson()).toList(),
  };
}
