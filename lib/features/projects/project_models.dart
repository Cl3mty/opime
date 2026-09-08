import '../investments/investments_models.dart' show generateInvestmentId;

/// Référence un [InvestmentAccount] entier — un projet suit la valeur de
/// tout le compte (ex : "le PEA Boursorama"), pas d'une position précise en
/// son sein : les positions d'un compte changent au fil des arbitrages,
/// alors que le compte qui finance un projet reste le même.
class ProjectAccountLink {
  final String accountId;

  const ProjectAccountLink({required this.accountId});

  factory ProjectAccountLink.fromJson(Map<String, dynamic> json) =>
      ProjectAccountLink(accountId: json['accountId'] as String? ?? '');

  Map<String, dynamic> toJson() => {'accountId': accountId};
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
/// principale", "Retraite") : une échéance, un rendement attendu, un apport
/// mensuel optionnel, un montant cible optionnel, et des comptes/passifs
/// existants qui y sont rattachés pour en suivre l'avancement (voir
/// `project_progress.dart`).
///
/// Un lien vers un compte/passif supprimé depuis n'est jamais purgé
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

  /// Versement mensuel régulier prévu (épargne programmée, virement
  /// automatique...) pris en compte dans la trajectoire projetée — voir
  /// `project_trajectory.dart`. `0` (défaut) : pas de versement récurrent,
  /// seule la valeur actuelle capitalise.
  final double apportMensuel;

  /// Montant cible en euros — `null` si le projet n'en a pas (l'avancement
  /// se limite alors au temps restant jusqu'à [echeance]).
  final double? montantCible;
  final List<ProjectAccountLink> accountLinks;
  final List<ProjectLiabilityLink> liabilityLinks;

  Project({
    String? id,
    required this.name,
    this.description = '',
    required this.echeance,
    this.rendementAttendu = 0,
    this.apportMensuel = 0,
    this.montantCible,
    this.accountLinks = const [],
    this.liabilityLinks = const [],
  }) : id = id ?? generateInvestmentId('projet');

  Project copyWith({
    String? name,
    String? description,
    DateTime? echeance,
    double? rendementAttendu,
    double? apportMensuel,
    double? montantCible,
    bool clearMontantCible = false,
    List<ProjectAccountLink>? accountLinks,
    List<ProjectLiabilityLink>? liabilityLinks,
  }) => Project(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    echeance: echeance ?? this.echeance,
    rendementAttendu: rendementAttendu ?? this.rendementAttendu,
    apportMensuel: apportMensuel ?? this.apportMensuel,
    montantCible: clearMontantCible
        ? null
        : (montantCible ?? this.montantCible),
    accountLinks: accountLinks ?? this.accountLinks,
    liabilityLinks: liabilityLinks ?? this.liabilityLinks,
  );

  /// Décodage tolérant aux anciennes données : un lien `actifs` sauvegardé
  /// avant l'introduction de [ProjectAccountLink] portait aussi un
  /// `investmentId` (position précise plutôt que compte entier) — ce champ
  /// est simplement ignoré ici, et les comptes en double qui en résultent
  /// (plusieurs positions du même compte autrefois liées séparément) sont
  /// dédupliqués.
  factory Project.fromJson(Map<String, dynamic> json) {
    final accountIds = <String>{};
    for (final e in (json['actifs'] as List? ?? [])) {
      final link = ProjectAccountLink.fromJson(e as Map<String, dynamic>);
      if (link.accountId.isNotEmpty) accountIds.add(link.accountId);
    }
    return Project(
      id: json['id'] as String? ?? generateInvestmentId('projet'),
      name: json['nom'] as String? ?? '',
      description: json['description'] as String? ?? '',
      echeance: DateTime.parse(json['echeance'] as String),
      rendementAttendu: (json['rendementAttendu'] as num?)?.toDouble() ?? 0,
      apportMensuel: (json['apportMensuel'] as num?)?.toDouble() ?? 0,
      montantCible: (json['montantCible'] as num?)?.toDouble(),
      accountLinks: [
        for (final accountId in accountIds)
          ProjectAccountLink(accountId: accountId),
      ],
      liabilityLinks: (json['passifs'] as List? ?? [])
          .map((e) => ProjectLiabilityLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': name,
    'description': description,
    'echeance': echeance.toIso8601String(),
    'rendementAttendu': rendementAttendu,
    if (apportMensuel != 0) 'apportMensuel': apportMensuel,
    if (montantCible != null) 'montantCible': montantCible,
    if (accountLinks.isNotEmpty)
      'actifs': accountLinks.map((a) => a.toJson()).toList(),
    if (liabilityLinks.isNotEmpty)
      'passifs': liabilityLinks.map((l) => l.toJson()).toList(),
  };
}
