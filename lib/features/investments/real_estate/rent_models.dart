/// Modèles de suivi locatif/travaux d'un bien immobilier — voir la doc de
/// tête de `Investment.rentPeriods`/`Investment.workItems`.
library;

import '../investments_models.dart' show generateInvestmentId;

/// Une période de loyer (généralement un mois) pour un bien immobilier
/// détenu — l'historique de ces périodes alimente le revenu locatif annuel
/// utilisé par la rentabilité (voir `real_estate_profitability_calculator
/// .dart`) et sert de base à la génération d'une quittance
/// (`quittance_pdf_builder.dart`, à venir).
class RentPeriod {
  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Montant dû pour la période (loyer + charges) — toujours renseigné, que
  /// la période soit payée ou non.
  final double amountDue;

  /// `null` tant que la période n'a pas été marquée payée — voir [isPaid].
  /// Distinct de [amountDue] : un paiement partiel reste possible (montant
  /// inférieur au dû).
  final double? amountPaid;
  final DateTime? paidAt;

  final String? tenantName;
  final String? note;

  bool get isPaid => paidAt != null;

  RentPeriod({
    String? id,
    required this.periodStart,
    required this.periodEnd,
    required this.amountDue,
    this.amountPaid,
    this.paidAt,
    this.tenantName,
    this.note,
  }) : id = id ?? generateInvestmentId('rent');

  RentPeriod copyWith({
    DateTime? periodStart,
    DateTime? periodEnd,
    double? amountDue,
    Object? amountPaid = _unset,
    Object? paidAt = _unset,
    Object? tenantName = _unset,
    Object? note = _unset,
  }) => RentPeriod(
    id: id,
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    amountDue: amountDue ?? this.amountDue,
    amountPaid: identical(amountPaid, _unset)
        ? this.amountPaid
        : (amountPaid as num?)?.toDouble(),
    paidAt: identical(paidAt, _unset) ? this.paidAt : paidAt as DateTime?,
    tenantName: identical(tenantName, _unset)
        ? this.tenantName
        : tenantName as String?,
    note: identical(note, _unset) ? this.note : note as String?,
  );

  factory RentPeriod.fromJson(Map<String, dynamic> json) => RentPeriod(
    id: json['id'] as String?,
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    amountDue: (json['amountDue'] as num?)?.toDouble() ?? 0,
    amountPaid: (json['amountPaid'] as num?)?.toDouble(),
    paidAt: json['paidAt'] != null
        ? DateTime.parse(json['paidAt'] as String)
        : null,
    tenantName: json['tenantName'] as String?,
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'amountDue': amountDue,
    if (amountPaid != null) 'amountPaid': amountPaid,
    if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
    if (tenantName != null) 'tenantName': tenantName,
    if (note != null) 'note': note,
  };
}

/// Un poste de travaux (rénovation, entretien lourd...) pour un bien
/// immobilier — alimente le coût total du projet utilisé par la
/// rentabilité, en plus du montant investi à l'achat
/// ([Investment.investedAmount]).
class WorkItem {
  final String id;
  final String label;

  /// Regroupement libre ("Gros œuvre", "Plomberie", "Électricité",
  /// "Peinture", "Mobilier", "Autre"...) — pas un enum fermé : la liste de
  /// suggestions vit côté UI, la donnée reste un texte libre pour ne pas
  /// bloquer sur une catégorie non prévue.
  final String? category;
  final double amount;
  final DateTime date;
  final String? note;

  /// Id du [Investment.documents] correspondant (la facture) — `null` sans
  /// document rattaché.
  final String? documentId;

  WorkItem({
    String? id,
    required this.label,
    this.category,
    required this.amount,
    required this.date,
    this.note,
    this.documentId,
  }) : id = id ?? generateInvestmentId('work');

  WorkItem copyWith({
    String? label,
    Object? category = _unset,
    double? amount,
    DateTime? date,
    Object? note = _unset,
    Object? documentId = _unset,
  }) => WorkItem(
    id: id,
    label: label ?? this.label,
    category: identical(category, _unset)
        ? this.category
        : category as String?,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    note: identical(note, _unset) ? this.note : note as String?,
    documentId: identical(documentId, _unset)
        ? this.documentId
        : documentId as String?,
  );

  factory WorkItem.fromJson(Map<String, dynamic> json) => WorkItem(
    id: json['id'] as String?,
    label: json['label'] as String? ?? '',
    category: json['category'] as String?,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String?,
    documentId: json['documentId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (category != null) 'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    if (note != null) 'note': note,
    if (documentId != null) 'documentId': documentId,
  };
}

const _unset = Object();
