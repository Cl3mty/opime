import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import '../../core/academy/academy_level.dart';
import '../../core/academy/academy_models.dart';
import 'academy_track.dart';

const _bourseSteps = [
  AcademyStep(
    id: 'formation_bourse_action',
    title: 'Qu\'est-ce qu\'une action ?',
    level: AcademyLevel.intermediaire,
    tagline: 'Une part de propriété dans une entreprise cotée.',
    bullets: [
      'Détenir une action, c\'est détenir une petite part de l\'entreprise.',
      'Le rendement vient de la hausse du cours et/ou des dividendes versés.',
      'Sa valeur peut monter comme descendre : c\'est un actif risqué.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Action',
        definition:
            'Titre représentant une part de propriété du capital d\'une entreprise.',
      ),
      GlossaryTerm(
        term: 'Dividende',
        definition:
            'Part des bénéfices qu\'une entreprise choisit de reverser à ses actionnaires.',
      ),
      GlossaryTerm(
        term: 'Capitalisation boursière',
        definition:
            'Valeur totale d\'une entreprise cotée (prix de l\'action × nombre d\'actions).',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_bourse_obligation',
    title: 'Qu\'est-ce qu\'une obligation ?',
    level: AcademyLevel.intermediaire,
    tagline: 'Un prêt que vous accordez à une entreprise ou un État.',
    bullets: [
      'En échange, l\'émetteur verse des intérêts réguliers (le coupon).',
      'Le capital est remboursé à l\'échéance, sauf défaut de l\'émetteur.',
      'Généralement moins volatile qu\'une action, mais pas sans risque.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Obligation',
        definition:
            'Titre de créance représentant un prêt fait à une entreprise ou un État.',
      ),
      GlossaryTerm(
        term: 'Coupon',
        definition:
            'Intérêt versé périodiquement au détenteur d\'une obligation.',
      ),
      GlossaryTerm(
        term: 'Échéance',
        definition:
            'Date à laquelle le capital prêté est remboursé à l\'investisseur.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_bourse_ordres',
    title: 'Les ordres de bourse',
    level: AcademyLevel.intermediaire,
    tagline: 'Comment passer concrètement un achat ou une vente en bourse.',
    bullets: [
      'Ordre au marché : exécuté immédiatement, au meilleur prix disponible.',
      'Ordre à cours limité : n\'est exécuté qu\'à un prix choisi à l\'avance, ou meilleur.',
      'Un ordre à cours limité protège du prix, mais n\'est pas garanti d\'être exécuté.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Ordre au marché',
        definition:
            'Ordre exécuté immédiatement, au meilleur prix disponible sur le marché.',
      ),
      GlossaryTerm(
        term: 'Ordre à cours limité',
        definition:
            'Ordre qui fixe un prix maximum (achat) ou minimum (vente) à ne pas dépasser.',
      ),
      GlossaryTerm(
        term: 'Spread',
        definition:
            'Écart entre le meilleur prix d\'achat et le meilleur prix de vente à un instant donné.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_bourse_cours',
    title: 'Lire un cours de bourse',
    level: AcademyLevel.avance,
    tagline: 'Comprendre les chiffres qui accompagnent un titre coté.',
    bullets: [
      'Le cours reflète le prix d\'équilibre entre acheteurs et vendeurs à un instant T.',
      'Le volume indique combien de titres ont échangé de mains sur la période.',
      'Une variation forte avec un faible volume est souvent moins significative.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Cours',
        definition: 'Dernier prix auquel un titre s\'est échangé.',
      ),
      GlossaryTerm(
        term: 'Volume',
        definition: 'Nombre de titres échangés sur une période donnée.',
      ),
      GlossaryTerm(
        term: 'Volatilité',
        definition:
            'Amplitude des variations de prix d\'un actif dans le temps.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_bourse_indices',
    title: 'Les indices boursiers',
    level: AcademyLevel.avance,
    tagline: 'Un thermomètre qui résume la santé d\'un marché.',
    bullets: [
      'Un indice regroupe un panier d\'actions représentatif d\'un marché (ex : CAC 40).',
      'Il sert de référence pour comparer la performance d\'un placement.',
      'C\'est aussi ce que répliquent la plupart des ETF.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Indice',
        definition:
            'Panier d\'actifs représentatif d\'un marché, utilisé comme référence de performance.',
      ),
      GlossaryTerm(
        term: 'Pondération',
        definition:
            'Poids relatif de chaque titre dans la composition d\'un indice.',
      ),
    ],
    takeaway:
        'Battre durablement un grand indice est très difficile, même pour des professionnels : c\'est ce qui a rendu les ETF si populaires.',
  ),
];

const _metauxSteps = [
  AcademyStep(
    id: 'formation_metaux_refuge',
    title: 'L\'or, valeur refuge',
    level: AcademyLevel.intermediaire,
    tagline: 'Un actif recherché en période d\'incertitude économique.',
    bullets: [
      'L\'or ne verse ni dividende ni intérêt : son rendement vient uniquement de sa valorisation.',
      'Historiquement peu corrélé aux actions, il diversifie un portefeuille.',
      'L\'argent métal suit une logique proche, avec plus de volatilité.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Valeur refuge',
        definition:
            'Actif recherché par les investisseurs pour préserver leur capital en période d\'incertitude.',
      ),
      GlossaryTerm(
        term: 'Once',
        definition:
            'Unité de référence pour coter l\'or et l\'argent (environ 31,1 grammes).',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_metaux_comment',
    title: 'Comment y investir',
    level: AcademyLevel.avance,
    tagline: 'Trois façons d\'être exposé aux métaux précieux.',
    bullets: [
      'Physique : pièces ou lingots, avec des frais de garde et d\'assurance.',
      'ETF adossés à de l\'or physique : plus liquide, sans stockage à gérer.',
      'Actions de sociétés minières : plus risquées, plus corrélées à la bourse.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Prime',
        definition:
            'Écart entre le prix payé pour une pièce/lingot et la valeur de son métal contenu.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_metaux_fiscalite',
    title: 'La fiscalité de l\'or physique',
    level: AcademyLevel.avance,
    tagline: 'Un régime particulier, différent des autres placements.',
    bullets: [
      'Taxe forfaitaire sur le prix de vente, sauf justificatif d\'achat conservé.',
      'Avec justificatif, option possible pour le régime des plus-values classique.',
      'Toujours conserver ses factures d\'achat.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Taxe forfaitaire',
        definition:
            'Taxe calculée sur le prix de vente total, sans tenir compte du prix d\'achat.',
      ),
    ],
    takeaway:
        'Sans facture d\'achat conservée, la taxe forfaitaire s\'applique automatiquement, même en cas de perte.',
  ),
];

const _cryptoSteps = [
  AcademyStep(
    id: 'formation_crypto_intro',
    title: 'Introduction aux cryptomonnaies',
    level: AcademyLevel.intermediaire,
    tagline: 'Comprendre les bases de la blockchain et des cryptomonnaies.',
    bullets: [
      'La blockchain est un registre décentralisé et immuable.',
      'Bitcoin est la première cryptomonnaie, Ethereum permet des contrats intelligents.',
      'Les cryptomonnaies sont volatiles et nécessitent une bonne gestion des risques.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Blockchain',
        definition: 'Technologie de registre distribué et sécurisé.',
      ),
      GlossaryTerm(
        term: 'Bitcoin',
        definition:
            'Première cryptomonnaie, utilisée comme réserve de valeur et moyen de paiement.',
      ),
      GlossaryTerm(
        term: 'Ethereum',
        definition:
            'Plateforme blockchain permettant la création de contrats intelligents et d\'applications décentralisées.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_crypto_investir',
    title: 'Comment investir',
    level: AcademyLevel.avance,
    tagline: 'Différentes façons d\'être exposé aux cryptomonnaies.',
    bullets: [
      'Acheter des cryptomonnaies sur des plateformes d\'échange.',
      'Investir via des ETF ou des fonds spécialisés.',
      'Participer à des projets blockchain via des tokens, plus risqué.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Token',
        definition:
            'Unité de valeur émise sur une blockchain, représentant un actif ou un droit.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_crypto_fiscalite',
    title: 'La fiscalité des cryptomonnaies',
    level: AcademyLevel.avance,
    tagline: 'Un régime particulier, différent des autres placements.',
    bullets: [
      'Les plus-values sur les cryptomonnaies sont imposées.',
      'Déclaration obligatoire des comptes sur plateformes étrangères.',
      'Conserver les justificatifs d\'achat pour optimiser la fiscalité.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Plus-value',
        definition:
            'Gain réalisé lors de la vente d\'un actif, imposable selon la législation en vigueur.',
      ),
    ],
    takeaway:
        'Bien documenter ses transactions pour une déclaration fiscale correcte.',
  ),
];

const _immobilierSteps = [
  AcademyStep(
    id: 'formation_immo_locatif',
    title: 'L\'immobilier locatif direct',
    level: AcademyLevel.intermediaire,
    tagline: 'Acheter un bien pour le louer et percevoir des loyers.',
    bullets: [
      'Rendement locatif brut = loyers annuels ÷ prix d\'achat, en %.',
      'Le rendement net retire charges, taxe foncière, vacance locative et travaux.',
      'Demande du temps de gestion, sauf délégation à une agence.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Rendement brut',
        definition: 'Loyers annuels rapportés au prix d\'achat, avant charges.',
      ),
      GlossaryTerm(
        term: 'Vacance locative',
        definition:
            'Période durant laquelle un bien reste inoccupé entre deux locataires.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_immo_scpi',
    title: 'Les SCPI',
    level: AcademyLevel.intermediaire,
    tagline: 'Investir dans l\'immobilier sans gérer de bien soi-même.',
    bullets: [
      'Une société achète et gère un parc immobilier pour le compte des porteurs de parts.',
      'Les loyers collectés sont reversés au prorata des parts détenues.',
      'Mise de départ plus faible qu\'un achat en direct, mais frais d\'entrée à surveiller.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'SCPI',
        definition:
            'Société civile qui collecte de l\'épargne pour investir et gérer un parc immobilier locatif.',
      ),
      GlossaryTerm(
        term: 'Taux de distribution',
        definition:
            'Revenu versé aux porteurs de parts, rapporté au prix de la part.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_immo_levier',
    title: 'L\'effet de levier du crédit',
    level: AcademyLevel.avance,
    tagline:
        'Investir avec l\'argent de la banque pour démultiplier son capital engagé.',
    bullets: [
      'Emprunter pour investir permet d\'acquérir un bien plus important que son épargne seule.',
      'Le levier amplifie les gains... mais aussi les pertes potentielles.',
      'Le coût du crédit doit rester inférieur au rendement espéré du bien.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Effet de levier',
        definition:
            'Utiliser l\'emprunt pour démultiplier la capacité d\'investissement au-delà de son épargne propre.',
      ),
      GlossaryTerm(
        term: 'Taux d\'endettement',
        definition:
            'Part des revenus consacrée au remboursement de crédits, encadrée par les banques.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_immo_fiscalite',
    title: 'Fiscalité des revenus locatifs',
    level: AcademyLevel.avance,
    tagline: 'Deux grands régimes possibles, aux logiques opposées.',
    bullets: [
      'Micro-foncier (location nue) : abattement forfaitaire de 30 % sur les loyers déclarés.',
      'Régime réel : déduction des charges réelles (travaux, intérêts d\'emprunt...), souvent plus avantageux si elles sont élevées.',
      'La location meublée (LMNP) permet en plus d\'amortir le bien, réduisant fortement le revenu imposable.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Micro-foncier',
        definition:
            'Régime fiscal simplifié avec abattement forfaitaire de 30 % sur les loyers d\'un bien loué nu.',
      ),
      GlossaryTerm(
        term: 'LMNP',
        definition:
            'Loueur en Meublé Non Professionnel : statut fiscal pour la location meublée, avec amortissement possible.',
      ),
      GlossaryTerm(
        term: 'Amortissement',
        definition:
            'Constatation comptable de la perte de valeur d\'un bien dans le temps, déductible du revenu imposable.',
      ),
    ],
    takeaway:
        'Le régime fiscal choisi peut faire varier du simple au double l\'impôt payé sur les mêmes loyers.',
  ),
];

const _structurationSteps = [
  AcademyStep(
    id: 'formation_structuration_statuts',
    title: 'Les statuts d\'entreprise',
    level: AcademyLevel.avance,
    tagline:
        'Le statut juridique détermine votre fiscalité, votre protection et votre régime social.',
    bullets: [
      'Entreprise individuelle (EI) : pas de société distincte, revenus imposés directement à l\'IR ; le patrimoine personnel reste en principe protégé depuis 2022.',
      'EURL/SARL, SASU/SAS : sociétés à part entière, responsabilité limitée aux apports, imposées à l\'impôt sur les sociétés (IS) par défaut.',
      'Dirigeant de SASU/SAS : régime social "assimilé salarié", plus protecteur mais plus coûteux que celui du gérant majoritaire d\'EURL/SARL (travailleur indépendant).',
      'Le bon statut dépend du projet (seul ou à plusieurs, besoin de lever des fonds, régime social souhaité) — pas seulement de la fiscalité.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'IS (impôt sur les sociétés)',
        definition:
            'Impôt prélevé sur le bénéfice d\'une société, avant toute distribution aux associés.',
      ),
      GlossaryTerm(
        term: 'Assimilé salarié',
        definition:
            'Régime social du dirigeant de SASU/SAS, proche de celui d\'un salarié classique (hors assurance chômage).',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_structuration_holding',
    title: 'La holding',
    level: AcademyLevel.avance,
    tagline:
        'Une société qui détient d\'autres sociétés, pour mutualiser et réinvestir sans frottement fiscal.',
    bullets: [
      'Une holding détient des parts ou actions d\'une ou plusieurs sociétés opérationnelles, plutôt que de les détenir en direct.',
      'Le régime mère-fille permet de faire remonter les dividendes des filiales vers la holding avec une fiscalité très réduite.',
      'Les bénéfices peuvent ainsi être réinvestis dans d\'autres projets sans passer d\'abord par le patrimoine personnel — et sa fiscalité immédiate.',
      'Utile pour organiser une transmission ou mutualiser une trésorerie entre plusieurs sociétés — pas un outil pour un patrimoine simple.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Holding',
        definition:
            'Société dont l\'objet est de détenir des participations dans d\'autres sociétés.',
      ),
      GlossaryTerm(
        term: 'Régime mère-fille',
        definition:
            'Régime fiscal réduisant fortement l\'imposition des dividendes remontés d\'une filiale vers sa société mère.',
      ),
    ],
    takeaway:
        'La holding n\'est pas un produit fiscal magique : elle a un coût de mise en place et de gestion, à mettre en regard du projet.',
  ),
  AcademyStep(
    id: 'formation_structuration_sci',
    title: 'La SCI',
    level: AcademyLevel.avance,
    tagline: 'Détenir et transmettre un bien immobilier à plusieurs, part par part.',
    bullets: [
      'Une SCI (société civile immobilière) détient un ou plusieurs biens ; les associés détiennent des parts sociales, pas le bien directement.',
      'À l\'IR (régime par défaut) : les loyers sont imposés comme des revenus fonciers classiques, entre les mains des associés.',
      'À l\'IS (sur option) : la société peut amortir le bien, réduisant le résultat imposable — mais la plus-value de revente devient moins favorable qu\'en détention directe.',
      'Transmettre des parts de SCI aux enfants, progressivement, est souvent plus simple à organiser qu\'un bien détenu en indivision.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'SCI',
        definition:
            'Société civile qui détient un ou plusieurs biens immobiliers pour le compte de ses associés.',
      ),
      GlossaryTerm(
        term: 'Indivision',
        definition:
            'Situation où plusieurs personnes détiennent ensemble un même bien, sans division en parts.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_structuration_dutreil',
    title: 'Le pacte Dutreil',
    level: AcademyLevel.avance,
    tagline: 'Transmettre une entreprise familiale avec un abattement de 75 % sur sa valeur.',
    bullets: [
      'Réservé à la transmission (donation ou succession) de titres d\'une société ayant une activité opérationnelle — pas une simple société de gestion de patrimoine.',
      'Exonération de 75 % de la valeur des titres transmis, sous engagement collectif puis individuel de conservation des titres pendant plusieurs années.',
      'L\'un des bénéficiaires doit poursuivre une fonction de direction dans la société pendant plusieurs années après la transmission.',
      'Un dispositif puissant mais engageant : rompre l\'engagement de conservation fait perdre l\'avantage fiscal, avec rappel d\'impôt.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Pacte Dutreil',
        definition:
            'Dispositif fiscal réduisant de 75 % la valeur taxable de titres d\'entreprise transmis, sous engagement de conservation.',
      ),
      GlossaryTerm(
        term: 'Engagement collectif de conservation',
        definition:
            'Engagement pris par plusieurs associés de conserver leurs titres pendant une durée minimale, condition du pacte Dutreil.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_structuration_demembrement',
    title: 'Le démembrement de propriété',
    level: AcademyLevel.avance,
    tagline: 'Séparer l\'usage d\'un bien (usufruit) de sa pleine propriété (nue-propriété).',
    bullets: [
      'La pleine propriété se divise en usufruit (droit d\'usage et d\'en percevoir les revenus) et nue-propriété (droit de disposer du bien, sans en jouir).',
      'Transmettre la nue-propriété tout en gardant l\'usufruit réduit fortement les droits de donation, calculés sur la seule valeur de la nue-propriété.',
      'À l\'extinction de l\'usufruit (souvent au décès de l\'usufruitier), le nu-propriétaire récupère la pleine propriété sans droits supplémentaires.',
      'Simulations > Transmission calcule cette répartition usufruit/nue-propriété selon l\'âge de l\'usufruitier, et son impact sur les droits de donation.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Usufruit',
        definition:
            'Droit d\'utiliser un bien et d\'en percevoir les revenus, sans en être pleinement propriétaire.',
      ),
      GlossaryTerm(
        term: 'Nue-propriété',
        definition:
            'Droit de disposer d\'un bien (le vendre, le transmettre) sans pouvoir l\'utiliser ni en percevoir les revenus.',
      ),
    ],
  ),
  AcademyStep(
    id: 'formation_structuration_donation',
    title: 'Les donations',
    level: AcademyLevel.avance,
    tagline: 'Transmettre de son vivant, en profitant d\'abattements renouvelables.',
    bullets: [
      'Chaque parent peut donner jusqu\'à 100 000 € par enfant tous les 15 ans, sans droits de donation.',
      'Des abattements spécifiques existent aussi pour les petits-enfants, le conjoint/partenaire de PACS, et entre frères et sœurs.',
      'Une donation-partage répartit les biens entre héritiers de son vivant, en figeant leur valeur au jour de la donation pour la succession à venir.',
      'Simulations > Transmission calcule les droits dus selon le lien de parenté et le montant donné.',
    ],
    vocabulary: [
      GlossaryTerm(
        term: 'Abattement',
        definition:
            'Montant déduit de la valeur transmise avant calcul des droits de donation ou de succession.',
      ),
      GlossaryTerm(
        term: 'Donation-partage',
        definition:
            'Donation qui répartit et fige, de son vivant, la valeur des biens transmis entre plusieurs héritiers.',
      ),
    ],
    takeaway:
        'Ces dispositifs se combinent (SCI démembrée, holding avec pacte Dutreil...) : une vue d\'ensemble mérite l\'avis d\'un notaire ou d\'un conseiller patrimonial.',
  ),
];

const formationTracks = [
  AcademyTrack(
    id: 'formation_bourse',
    title: 'Bourse',
    description: 'Actions, obligations, ordres et marchés financiers.',
    icon: LucideIcons.chartCandlestick,
    steps: _bourseSteps,
  ),
  AcademyTrack(
    id: 'formation_metaux',
    title: 'Métaux précieux',
    description: 'Or, argent, comment s\'y exposer et leur fiscalité.',
    icon: LucideIcons.gem,
    steps: _metauxSteps,
  ),
  AcademyTrack(
    id: 'formation_crypto',
    title: 'Crypto',
    description: 'Blockchain, Bitcoin, Ethereum et autres cryptomonnaies.',
    icon: LucideIcons.bitcoin,
    steps: _cryptoSteps,
  ),
  AcademyTrack(
    id: 'formation_immobilier',
    title: 'Immobilier',
    description: 'Locatif direct, SCPI, effet de levier et fiscalité.',
    icon: LucideIcons.house,
    steps: _immobilierSteps,
  ),
  AcademyTrack(
    id: 'formation_structuration',
    title: 'Structuration patrimoniale',
    description:
        'Statuts d\'entreprise, holding, SCI, pacte Dutreil, démembrement et donation.',
    icon: LucideIcons.network,
    steps: _structurationSteps,
  ),
];
