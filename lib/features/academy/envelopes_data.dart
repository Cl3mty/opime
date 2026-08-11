import '../../core/academy/academy_level.dart';
import '../../core/academy/academy_models.dart';

/// Fiches récapitulatives des enveloppes financières françaises, de la plus
/// simple à la plus riche en subtilités fiscales.
const envelopes = [
  Envelope(
    id: 'envelope_compte_courant',
    name: 'Compte courant',
    level: AcademyLevel.debutant,
    tagline: 'Le compte du quotidien : encaisser, payer, rien de plus.',
    ceiling: 'Aucun plafond',
    taxation: 'Aucun avantage fiscal, ne génère aucun revenu à déclarer',
    liquidity: 'Totale et immédiate',
    idealFor: 'Les dépenses courantes, jamais pour épargner durablement',
    goodToKnow: [
      'Un compte courant ne rapporte rien : l\'argent qui y dort perd du pouvoir d\'achat face à l\'inflation.',
      'Ne garder que le nécessaire pour les dépenses du mois, le reste doit être orienté vers une enveloppe adaptée.',
    ],
    pitfall:
        'Laisser dormir une épargne de précaution entière sur un compte courant plutôt que sur un Livret A.',
  ),
  Envelope(
    id: 'envelope_livret_a',
    name: 'Livret A',
    level: AcademyLevel.debutant,
    tagline:
        'L\'épargne de précaution par excellence, sans risque et sans impôt.',
    ceiling: '22 950 €',
    taxation:
        'Intérêts exonérés d\'impôt sur le revenu et de prélèvements sociaux',
    liquidity: 'Totale, retrait possible à tout moment sans pénalité',
    idealFor: 'L\'épargne de précaution (3 à 6 mois de dépenses courantes)',
    goodToKnow: [
      'Le taux est fixé par l\'État et révisé périodiquement selon l\'inflation et les taux du marché.',
      'Un seul Livret A par personne est autorisé.',
      'Les intérêts sont calculés par quinzaine : un versement en tout début ou toute fin de quinzaine optimise les intérêts.',
    ],
    pitfall:
        'Y accumuler bien plus que le nécessaire pour la sécurité, au détriment de placements plus rémunérateurs.',
  ),
  Envelope(
    id: 'envelope_ldds',
    name: 'LDDS',
    level: AcademyLevel.debutant,
    tagline:
        'Le cousin du Livret A, orienté vers le financement de l\'économie sociale et solidaire.',
    ceiling: '12 000 €',
    taxation:
        'Intérêts exonérés d\'impôt sur le revenu et de prélèvements sociaux',
    liquidity: 'Totale, retrait possible à tout moment sans pénalité',
    idealFor: 'Compléter le Livret A une fois son plafond atteint',
    goodToKnow: [
      'Mêmes conditions de taux et de fiscalité que le Livret A.',
      'Réservé aux personnes majeures fiscalement domiciliées en France.',
      'Une partie des fonds collectés finance des projets d\'économie sociale et solidaire.',
    ],
    pitfall:
        'Ignorer le LDDS en pensant, à tort, qu\'il est moins intéressant que le Livret A : les conditions sont identiques.',
  ),
  Envelope(
    id: 'envelope_lep',
    name: 'LEP',
    level: AcademyLevel.intermediaire,
    tagline:
        'Le livret réglementé le plus généreux, réservé aux revenus modestes.',
    ceiling: '10 000 €',
    taxation:
        'Intérêts exonérés d\'impôt sur le revenu et de prélèvements sociaux',
    liquidity: 'Totale, retrait possible à tout moment sans pénalité',
    idealFor: 'Les foyers éligibles cherchant le meilleur taux sans risque',
    goodToKnow: [
      'L\'éligibilité dépend du revenu fiscal de référence, réévaluée chaque année.',
      'Le taux est généralement supérieur à celui du Livret A.',
      'À vérifier chaque année : on peut perdre l\'éligibilité si les revenus augmentent.',
    ],
    pitfall:
        'Ne pas vérifier son éligibilité chaque année alors que la situation fiscale a changé.',
  ),
  Envelope(
    id: 'envelope_pel',
    name: 'PEL',
    level: AcademyLevel.intermediaire,
    tagline: 'Une épargne fléchée vers un futur projet immobilier.',
    ceiling: '61 200 € de versements',
    taxation:
        'Intérêts fiscalisés (impôt et prélèvements sociaux), régime variable selon la date d\'ouverture',
    liquidity: 'Bloquée sans perte d\'avantages pendant les 4 premières années',
    idealFor: 'Préparer un achat immobilier à moyen terme',
    goodToKnow: [
      'Le taux est fixé une fois pour toutes à l\'ouverture et garanti sur toute la durée du plan.',
      'Ouvre droit, sous conditions, à un prêt immobilier à un taux connu dès l\'ouverture.',
      'Un versement minimum annuel est requis pour ne pas clôturer le plan prématurément.',
    ],
    pitfall:
        'Ouvrir un PEL sans projet immobilier réel : son rendement est rarement compétitif comparé à d\'autres enveloppes.',
  ),
  Envelope(
    id: 'envelope_cto',
    name: 'Compte-titres ordinaire (CTO)',
    level: AcademyLevel.intermediaire,
    tagline:
        'Le compte le plus flexible pour investir en bourse, sans cadre fiscal privilégié.',
    ceiling: 'Aucun plafond',
    taxation:
        'Gains imposés au prélèvement forfaitaire unique de 30 % (ou barème progressif sur option)',
    liquidity: 'Totale, mais vendre déclenche potentiellement une imposition',
    idealFor: 'Investir sans limite de montant ni de zone géographique',
    goodToKnow: [
      'Accès à toutes les classes d\'actifs : actions du monde entier, ETF, obligations, produits dérivés...',
      'Peut être ouvert par une personne mineure, contrairement au PEA.',
      'Aucune contrainte de durée de détention pour bénéficier d\'un régime fiscal avantageux.',
    ],
    pitfall:
        'Multiplier les allers-retours (achats/ventes) sans mesurer l\'impact fiscal cumulé de chaque plus-value réalisée.',
  ),
  Envelope(
    id: 'envelope_pea',
    name: 'PEA',
    level: AcademyLevel.avance,
    tagline:
        'Investir en actions européennes avec un cadre fiscal avantageux après 5 ans.',
    ceiling: '150 000 €',
    taxation:
        'Gains exonérés d\'impôt sur le revenu après 5 ans (prélèvements sociaux toujours dus)',
    liquidity:
        'Un retrait avant 5 ans a longtemps entraîné la clôture du plan : vérifier les règles en vigueur',
    idealFor: 'Investir en actions européennes sur le long terme',
    goodToKnow: [
      'Réservé aux actions et fonds éligibles de sociétés européennes.',
      'Un seul PEA par personne (hors PEA-PME complémentaire).',
      'Plus l\'argent y reste longtemps après les 5 ans, plus l\'avantage fiscal se rentabilise.',
    ],
    pitfall:
        'Retirer des fonds avant 5 ans sans avoir vérifié les conséquences sur la clôture du plan et la fiscalité applicable.',
  ),
  Envelope(
    id: 'envelope_assurance_vie',
    name: 'Assurance-vie',
    level: AcademyLevel.avance,
    tagline:
        'Le couteau suisse de l\'épargne française : placement et transmission.',
    ceiling: 'Aucun plafond',
    taxation:
        'Fiscalité dégressive avec l\'ancienneté du contrat, nettement plus favorable après 8 ans',
    liquidity:
        'Rachats possibles à tout moment, mais moins avantageux fiscalement avant 8 ans',
    idealFor: 'Épargner à moyen/long terme tout en préparant sa transmission',
    goodToKnow: [
      'Mélange fonds euro (capital sécurisé, rendement modéré) et unités de compte (potentiel plus élevé, capital non garanti).',
      'Permet de transmettre un capital hors du cadre classique de la succession, avec un abattement dédié par bénéficiaire.',
      'Gestion libre (vous choisissez) ou pilotée (déléguée selon un profil de risque).',
    ],
    pitfall:
        'Clôturer un contrat juste avant son 8ᵉ anniversaire, en perdant l\'abattement fiscal annuel qui s\'active à cette date.',
  ),
  Envelope(
    id: 'envelope_contrat_capitalisation',
    name: 'Contrat de capitalisation',
    level: AcademyLevel.avance,
    tagline:
        'Le jumeau de l\'assurance-vie, sans clause de dénouement au décès.',
    ceiling: 'Aucun plafond',
    taxation:
        'Fiscalité des rachats identique à l\'assurance-vie, dégressive avec l\'ancienneté du contrat',
    liquidity:
        'Rachats possibles à tout moment, mêmes conditions que l\'assurance-vie',
    idealFor:
        'Les personnes morales (SCI, holding...) ou la transmission par donation en conservant l\'antériorité fiscale',
    goodToKnow: [
      'Contrairement à l\'assurance-vie, il peut être souscrit par une personne morale (société, association...), pas seulement une personne physique.',
      'Il n\'est pas dénoué au décès du souscripteur : il entre dans la succession et peut être transmis par donation en conservant son antériorité fiscale.',
      'Mêmes supports d\'investissement que l\'assurance-vie : fonds euros et unités de compte.',
    ],
    pitfall:
        'Le confondre avec l\'assurance-vie : au décès, il entre dans l\'actif successoral et ne bénéficie donc pas de l\'abattement spécifique dont profitent les bénéficiaires d\'une assurance-vie.',
  ),
  Envelope(
    id: 'envelope_pee_peg',
    name: 'PEE / PEG',
    level: AcademyLevel.avance,
    tagline: 'L\'épargne salariale : l\'entreprise abonde, vous épargnez.',
    ceiling:
        'Pas de plafond réglementaire propre (limité par les versements issus de l\'épargne salariale)',
    taxation:
        'Plus-values exonérées d\'impôt sur le revenu (prélèvements sociaux dus)',
    liquidity: 'Bloqué 5 ans, sauf cas de déblocage anticipé prévus par la loi',
    idealFor:
        'Les salariés dont l\'entreprise propose un dispositif d\'épargne salariale',
    goodToKnow: [
      'Alimenté par l\'intéressement, la participation et des versements volontaires.',
      'L\'employeur peut ajouter un abondement : de l\'argent gratuit qui vient compléter vos versements.',
      'Les cas de déblocage anticipé incluent l\'achat de la résidence principale, le mariage, la naissance d\'un enfant...',
    ],
    pitfall:
        'Laisser l\'épargne salariale sur des fonds par défaut peu diversifiés sans jamais vérifier son allocation.',
  ),
  Envelope(
    id: 'envelope_per',
    name: 'PER',
    level: AcademyLevel.avance,
    tagline:
        'Préparer sa retraite en réduisant son impôt aujourd\'hui, au prix d\'un blocage long.',
    ceiling:
        'Déduction plafonnée à un pourcentage des revenus professionnels (variable selon la situation)',
    taxation:
        'Versements déductibles du revenu imposable à l\'entrée, sortie fiscalisée (capital et/ou rente)',
    liquidity:
        'Bloqué jusqu\'à la retraite, sauf accidents de la vie ou achat de la résidence principale',
    idealFor:
        'Les contribuables fortement imposés qui visent une épargne retraite de long terme',
    goodToKnow: [
      'A remplacé les anciens contrats PERP, Madelin et Article 83, qui peuvent y être transférés.',
      'La déduction à l\'entrée n\'a de sens que si la tranche marginale d\'imposition à la sortie est plus basse qu\'aujourd\'hui.',
      'Possibilité de sortie en capital, en rente viagère, ou un mélange des deux.',
    ],
    pitfall:
        'Verser sur un PER sans tenir compte du blocage jusqu\'à la retraite ni de la fiscalité à la sortie, qui peut surprendre.',
  ),
];
