import '../../core/academy/academy_level.dart';
import '../../core/academy/academy_models.dart';

/// Notions clés d'investissement, présentées comme des cartes de
/// mémorisation indépendantes, du pourquoi aux mécanismes de construction
/// d'une stratégie.
const investissementCards = [
  AcademyStep(
    id: 'invest_pourquoi',
    title: 'Pourquoi investir ?',
    level: AcademyLevel.debutant,
    tagline: 'Faire travailler son argent plutôt que de le laisser dormir.',
    bullets: [
      'L\'argent qui ne bouge pas perd de la valeur avec le temps (inflation).',
      'Investir, c\'est accepter un risque mesuré pour viser un rendement.',
      'L\'objectif : préserver, puis augmenter son pouvoir d\'achat dans la durée.',
      'Ce n\'est pas réservé aux experts : commencer petit et régulièrement suffit à démarrer.',
    ],
    takeaway:
        'Ne pas investir, c\'est aussi prendre un risque : celui de voir son épargne perdre de la valeur.',
  ),
  AcademyStep(
    id: 'invest_inflation',
    title: 'L\'inflation',
    level: AcademyLevel.debutant,
    tagline:
        'La hausse générale des prix qui érode la valeur de l\'épargne dormante.',
    bullets: [
      'Avec 2 % d\'inflation par an, 100 € valent environ 82 € de pouvoir d\'achat 10 ans plus tard.',
      'Un livret non rémunéré (ou peu) perd donc silencieusement de la valeur réelle.',
      'Investir vise, a minima, à compenser cette érosion, puis à générer un gain réel au-delà.',
    ],
    takeaway:
        'Le vrai rendement à surveiller est le rendement "réel" : rendement obtenu moins inflation.',
  ),
  AcademyStep(
    id: 'invest_risque',
    title: 'Le risque',
    level: AcademyLevel.debutant,
    tagline: 'Pas de rendement espéré sans un risque accepté en échange.',
    bullets: [
      'Volatilité (les prix bougent, parfois beaucoup) ne veut pas dire perte définitive.',
      'Plus l\'horizon de placement est long, plus le risque perçu diminue statistiquement.',
      'Ne jamais investir de l\'argent dont on peut avoir besoin à court terme.',
      'Le risque se gère : diversification, horizon adapté, montants raisonnables.',
    ],
    takeaway:
        'La perte n\'est réelle que si l\'on vend au mauvais moment : le temps est le meilleur allié contre le risque.',
  ),
  AcademyStep(
    id: 'invest_diversification',
    title: 'La diversification',
    level: AcademyLevel.intermediaire,
    tagline: 'Ne jamais mettre tous ses œufs dans le même panier.',
    bullets: [
      'Répartir entre classes d\'actifs (actions, obligations, immobilier...).',
      'Répartir entre zones géographiques et secteurs économiques.',
      'Réduit l\'impact d\'un accident isolé (une entreprise, un secteur, un pays) sur l\'ensemble du portefeuille.',
    ],
    takeaway:
        'Diversifier ne garantit pas de gagner plus, mais réduit fortement le risque de tout perdre.',
  ),
  AcademyStep(
    id: 'invest_etf',
    title: 'La révolution des ETF',
    level: AcademyLevel.intermediaire,
    tagline: 'Un fonds qui réplique un indice entier, en un seul achat.',
    bullets: [
      'ETF = fonds coté qui suit un indice (ex : CAC 40, MSCI World).',
      'Gestion passive : pas de sélection active de titres par un gérant.',
      'Diversification immédiate, pour un coût très inférieur aux fonds de gestion active.',
      'Ont démocratisé l\'accès à des portefeuilles diversifiés pour les particuliers.',
    ],
    takeaway:
        'Un seul ETF "monde" peut suffire à détenir des milliers d\'entreprises en une transaction.',
  ),
  AcademyStep(
    id: 'invest_frais',
    title: 'Les frais',
    level: AcademyLevel.intermediaire,
    tagline: 'Le facteur silencieux qui grignote la performance sur la durée.',
    bullets: [
      'Frais de gestion annuels, d\'entrée, d\'arbitrage : ils s\'additionnent année après année.',
      '1 % de frais par an, c\'est déjà significatif cumulé sur 20-30 ans.',
      'Toujours comparer les frais avant de comparer les performances passées.',
    ],
    takeaway:
        '1 % de frais annuel en plus peut représenter des dizaines de milliers d\'euros en moins à l\'arrivée.',
  ),
  AcademyStep(
    id: 'invest_fiscalite',
    title: 'La fiscalité',
    level: AcademyLevel.intermediaire,
    tagline: 'Un facteur d\'optimisation, jamais un motif d\'investir.',
    bullets: [
      'On choisit d\'abord un investissement pour son couple rendement/risque, cohérent avec un projet et ses propres convictions.',
      'La fiscalité s\'optimise ensuite, à stratégie inchangée : par exemple, loger des actions européennes dans un PEA plutôt qu\'un CTO pour profiter de son cadre fiscal après 5 ans de détention.',
      'Chaque enveloppe (PEA, assurance vie, CTO, PER...) a ses propres règles de taxation et de disponibilité de l\'argent — voir les fiches Enveloppes.',
      'Un placement fiscalement avantageux mais mal aligné avec son horizon, son risque ou ses convictions reste un mauvais choix.',
    ],
    takeaway:
        'D\'abord le bon investissement, ensuite la bonne enveloppe fiscale pour le loger — jamais l\'inverse.',
  ),
  AcademyStep(
    id: 'invest_pyramide',
    title: 'La pyramide de l\'investissement',
    level: AcademyLevel.avance,
    tagline:
        'Construire son patrimoine étage par étage, du plus sûr au plus risqué.',
    bullets: [
      'Base : épargne de précaution, liquide et sans risque (3 à 6 mois de dépenses).',
      'Milieu : investissements diversifiés à moyen/long terme (ETF, immobilier...).',
      'Sommet : placements plus risqués et spéculatifs, en petite proportion seulement.',
      'On ne monte à l\'étage supérieur qu\'une fois l\'étage inférieur consolidé.',
    ],
    takeaway:
        'Sans base solide (épargne de précaution), le reste de la pyramide est fragile.',
  ),
  AcademyStep(
    id: 'invest_allocation',
    title: 'Allocation stratégique vs dynamique',
    level: AcademyLevel.avance,
    tagline: 'Deux philosophies pour répartir son portefeuille dans le temps.',
    bullets: [
      'Stratégique : une répartition cible fixée selon son profil, tenue sur la durée.',
      'Dynamique : des ajustements tactiques selon les conditions de marché.',
      'La première demande de la discipline, la seconde du temps et de l\'expertise.',
      'La majorité des investisseurs particuliers gagnent à privilégier une approche stratégique simple.',
    ],
    takeaway:
        'Changer d\'allocation trop souvent coûte généralement plus cher (frais, erreurs de timing) que cela ne rapporte.',
  ),
  AcademyStep(
    id: 'invest_temps_long',
    title: 'Le temps long',
    level: AcademyLevel.avance,
    tagline:
        'Le meilleur allié de l\'investisseur, grâce aux intérêts composés.',
    bullets: [
      'Les intérêts composés font grossir un capital de façon exponentielle, pas linéaire.',
      '« Le temps passé sur le marché bat le fait de vouloir le timer. »',
      'Investir à intervalles réguliers (DCA) lisse les points d\'entrée dans le temps.',
    ],
    takeaway:
        'La majorité des gains d\'un investissement long terme se concentrent souvent sur les dernières années : ne pas sortir trop tôt.',
  ),
];
