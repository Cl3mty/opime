import '../investments/investments_models.dart' show generateInvestmentId;

/// Référence un [Investment] précis à l'intérieur d'un [InvestmentAccount] —
/// [Investment.id] seul ne suffit pas à le retrouver sans parcourir tous les
/// comptes, les investissements étant imbriqués sous leur compte porteur.
class ProjectAssetLink {
  final String accountId;
  final String investmentId;

  const ProjectAssetLink({required this.accountId, required this.investmentId});

  factory ProjectAssetLink.fromJson(Map<String, dynamic> json) =>
      ProjectAssetLink(
        accountId: json['accountId'] as String? ?? '',
        investmentId: json['investmentId'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'investmentId': investmentId,
  };
}

/// Référence un [Liability] par id.
class ProjectLiabilityLink {
  final String liabilityId;

  const ProjectLiabilityLink({required this.liabilityId});

  factory ProjectLiabilityLink.fromJson(Map<String, dynamic> json) =>
      ProjectLiabilityLink(liabilityId: json['liabilityId'] as String? ?? '');

  Map<String, dynamic> toJson() => {'liabilityId': liabilityId};
}

/// Un projet financier créé par l'utilisateur (ex : "Achat résidence
/// principale", "Retraite") : une échéance, un rendement attendu, un
/// montant cible optionnel, et des actifs/passifs existants qui y sont
/// rattachés pour en suivre l'avancement (voir `project_progress.dart`).
///
/// Un lien vers un actif/passif supprimé depuis n'est jamais purgé
/// automatiquement ici (ce repository ne connaît pas les autres) : c'est à
/// l'appelant (`project_progress.dart`, `project_editor.dart`) de traiter un
/// id qui ne se résout plus comme une contribution nulle, jamais comme une
/// erreur.
class Project {
  final String id;
  final String name;
  final String description;
  final DateTime echeance;

  /// Rendement annuel attendu, en %.
  final double rendementAttendu;

  /// Montant cible en euros — `null` si le projet n'en a pas (l'avancement
  /// se limite alors au temps restant jusqu'à [echeance]).
  final double? montantCible;
  final List<ProjectAssetLink> assetLinks;
  final List<ProjectLiabilityLink> liabilityLinks;

  Project({
    String? id,
    required this.name,
    this.description = '',
    required this.echeance,
    this.rendementAttendu = 0,
    this.montantCible,
    this.assetLinks = const [],
    this.liabilityLinks = const [],
  }) : id = id ?? generateInvestmentId('projet');

  Project copyWith({
    String? name,
    String? description,
    DateTime? echeance,
    double? rendementAttendu,
    double? montantCible,
    bool clearMontantCible = false,
    List<ProjectAssetLink>? assetLinks,
    List<ProjectLiabilityLink>? liabilityLinks,
  }) => Project(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    echeance: echeance ?? this.echeance,
    rendementAttendu: rendementAttendu ?? this.rendementAttendu,
    montantCible: clearMontantCible
        ? null
        : (montantCible ?? this.montantCible),
    assetLinks: assetLinks ?? this.assetLinks,
    liabilityLinks: liabilityLinks ?? this.liabilityLinks,
  );

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String? ?? generateInvestmentId('projet'),
    name: json['nom'] as String? ?? '',
    description: json['description'] as String? ?? '',
    echeance: DateTime.parse(json['echeance'] as String),
    rendementAttendu: (json['rendementAttendu'] as num?)?.toDouble() ?? 0,
    montantCible: (json['montantCible'] as num?)?.toDouble(),
    assetLinks: (json['actifs'] as List? ?? [])
        .map((e) => ProjectAssetLink.fromJson(e as Map<String, dynamic>))
        .toList(),
    liabilityLinks: (json['passifs'] as List? ?? [])
        .map((e) => ProjectLiabilityLink.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'description': description,
    'echeance': echeance.toIso8601String(),
    'rendementAttendu': rendementAttendu,
    if (montantCible != null) 'montantCible': montantCible,
    if (assetLinks.isNotEmpty)
      'actifs': assetLinks.map((a) => a.toJson()).toList(),
    if (liabilityLinks.isNotEmpty)
      'passifs': liabilityLinks.map((l) => l.toJson()).toList(),
  };
}
