import 'budget_tracking_models.dart' show generateTrackingItemId;

/// Section du suivi de budget concernée par un [RecurringTemplate] — mêmes
/// six sections que [BudgetTrackingMonth] (`revenues`/`factures`/
/// `depenses`/`investEpargnes`/`projets`/`dettes`), nécessaire ici car les
/// templates ne sont pas déjà scopés par section comme le sont les listes
/// de [TrackingItem] dans l'écran (un seul fichier plat, voir
/// `BudgetRecurringTemplatesRepository`).
enum BudgetSection { revenue, facture, depense, investEpargne, projet, dette }

/// Ligne récurrente réutilisable d'un mois à l'autre dans le suivi de
/// budget (ex : un loyer, un abonnement) — un simple point de départ à la
/// copie dans un mois donné (voir `RecurringTemplatesDialog`'s "Appliquer
/// maintenant"), PAS une règle vivante : éditer ou supprimer un template
/// plus tard ne modifie jamais les [TrackingItem] déjà créés à partir de
/// lui dans un mois passé.
class RecurringTemplate {
  final String id;
  final String name;
  final double amount;
  final String category; // vide = non catégorisé, comme TrackingItem
  final BudgetSection section;

  RecurringTemplate({
    String? id,
    required this.name,
    required this.amount,
    this.category = '',
    required this.section,
  }) : id = id ?? generateTrackingItemId('tmpl');

  RecurringTemplate copyWith({
    String? name,
    double? amount,
    String? category,
  }) => RecurringTemplate(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    section: section,
  );

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) =>
      RecurringTemplate(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? '',
        section: BudgetSection.values.firstWhere(
          (s) => s.name == json['section'],
          orElse: () => BudgetSection.depense,
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'category': category,
    'section': section.name,
  };
}
