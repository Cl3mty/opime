import 'dart:math';

import '../../core/date_format.dart';

String generateItemId(String prefix) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  final suffix = List.generate(
    8,
    (_) => chars[rand.nextInt(chars.length)],
  ).join();
  return '${prefix}_$suffix';
}

class BudgetItem {
  final String id;
  final String name;
  final double amount;

  BudgetItem({required this.id, required this.name, required this.amount});

  BudgetItem copyWith({String? name, double? amount}) => BudgetItem(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
  );

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount};
}

class BudgetCategory {
  final String id;
  final String name;
  final List<BudgetItem> items;

  BudgetCategory({String? id, required this.name, required this.items})
    : id = id ?? generateItemId('category');

  BudgetCategory copyWith({String? name, List<BudgetItem>? items}) =>
      BudgetCategory(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
    id: json['id'] as String? ?? generateItemId('category'),
    name: json['name'] as String? ?? '',
    items: (json['items'] as List? ?? [])
        .map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class BudgetData {
  final List<BudgetItem> revenues;
  final List<BudgetCategory> expenseCategories;
  final List<BudgetCategory> investmentCategories;

  BudgetData({
    required this.revenues,
    required this.expenseCategories,
    required this.investmentCategories,
  });

  factory BudgetData.empty() =>
      BudgetData(revenues: [], expenseCategories: [], investmentCategories: []);

  BudgetData copyWith({
    List<BudgetItem>? revenues,
    List<BudgetCategory>? expenseCategories,
    List<BudgetCategory>? investmentCategories,
  }) => BudgetData(
    revenues: revenues ?? this.revenues,
    expenseCategories: expenseCategories ?? this.expenseCategories,
    investmentCategories: investmentCategories ?? this.investmentCategories,
  );

  factory BudgetData.fromJson(Map<String, dynamic> json) => BudgetData(
    revenues: (json['revenues'] as List? ?? [])
        .map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    expenseCategories:
        ((json['expenses'] as Map<String, dynamic>?)?['categories'] as List? ??
                [])
            .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
    investmentCategories:
        ((json['investments'] as Map<String, dynamic>?)?['categories']
                    as List? ??
                [])
            .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
  );

  Map<String, dynamic> toJson() => {
    'revenues': revenues.map((r) => r.toJson()).toList(),
    'expenses': {
      'categories': expenseCategories.map((c) => c.toJson()).toList(),
    },
    'investments': {
      'categories': investmentCategories.map((c) => c.toJson()).toList(),
    },
  };

  double get totalRevenues => revenues.fold(0, (sum, r) => sum + r.amount);

  double get totalExpenses => expenseCategories.fold(
    0,
    (sum, c) => sum + c.items.fold(0, (s, i) => s + i.amount),
  );

  double get totalInvestments => investmentCategories.fold(
    0,
    (sum, c) => sum + c.items.fold(0, (s, i) => s + i.amount),
  );

  double get balance => totalRevenues - totalExpenses - totalInvestments;

  double get savingsRate =>
      totalRevenues > 0 ? (totalInvestments / totalRevenues * 100) : 0;

  double get possibleSavingsRate => totalRevenues > 0
      ? ((totalRevenues - totalExpenses) / totalRevenues * 100)
      : 0;
}

class BudgetSnapshot {
  final String id;
  final String? name;
  final DateTime savedAt;
  final BudgetData data;

  BudgetSnapshot({
    required this.id,
    this.name,
    required this.savedAt,
    required this.data,
  });

  String get displayName => name?.isNotEmpty == true
      ? name!
      : 'Budget du ${formatDateDdMmYyyy(savedAt)}';

  factory BudgetSnapshot.fromJson(Map<String, dynamic> json) => BudgetSnapshot(
    id: json['id'] as String,
    name: json['name'] as String?,
    savedAt: DateTime.parse(json['savedAt'] as String),
    data: BudgetData.fromJson(json['data'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    'savedAt': savedAt.toIso8601String(),
    'data': data.toJson(),
  };
}
