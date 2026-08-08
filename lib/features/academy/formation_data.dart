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
      GlossaryTerm(term: 'Action', definition: 'Titre représentant une part de propriété du capital d\'une entreprise.'),
      GlossaryTerm(term: 'Dividende', definition: 'Part des bénéfices qu\'une entreprise choisit de reverser à ses actionnaires.'),
      GlossaryTerm(term: 'Capitalisation boursière', definition: 'Valeur totale d\'une entreprise cotée (prix de l\'action × nombre d\'actions).'),
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
      GlossaryTerm(term: 'Obligation', definition: 'Titre de créance représentant un prêt fait à une entreprise ou un État.'),
      GlossaryTerm(term: 'Coupon', definition: 'Intérêt versé périodiquement au détenteur d\'une obligation.'),
      GlossaryTerm(term: 'Échéance', definition: 'Date à laquelle le capital prêté est remboursé à l\'investisseur.'),
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
      GlossaryTerm(term: 'Ordre au marché', definition: 'Ordre exécuté immédiatement, au meilleur prix disponible sur le marché.'),
      GlossaryTerm(term: 'Ordre à cours limité', definition: 'Ordre qui fixe un prix maximum (achat) ou minimum (vente) à ne pas dépasser.'),
      GlossaryTerm(term: 'Spread', definition: 'Écart entre le meilleur prix d\'achat et le meilleur prix de vente à un instant donné.'),
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
      GlossaryTerm(term: 'Cours', definition: 'Dernier prix auquel un titre s\'est échangé.'),
      GlossaryTerm(term: 'Volume', definition: 'Nombre de titres échangés sur une période donnée.'),
      GlossaryTerm(term: 'Volatilité', definition: 'Amplitude des variations de prix d\'un actif dans le temps.'),
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
      GlossaryTerm(term: 'Indice', definition: 'Panier d\'actifs représentatif d\'un marché, utilisé comme référence de performance.'),
      GlossaryTerm(term: 'Pondération', definition: 'Poids relatif de chaque titre dans la composition d\'un indice.'),
    ],
    takeaway: 'Battre durablement un grand indice est très difficile, même pour des professionnels : c\'est ce qui a rendu les ETF si populaires.',
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
      GlossaryTerm(term: 'Valeur refuge', definition: 'Actif recherché par les investisseurs pour préserver leur capital en période d\'incertitude.'),
      GlossaryTerm(term: 'Once', definition: 'Unité de référence pour coter l\'or et l\'argent (environ 31,1 grammes).'),
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
      GlossaryTerm(term: 'Prime', definition: 'Écart entre le prix payé pour une pièce/lingot et la valeur de son métal contenu.'),
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
      GlossaryTerm(term: 'Taxe forfaitaire', definition: 'Taxe calculée sur le prix de vente total, sans tenir compte du prix d\'achat.'),
    ],
    takeaway: 'Sans facture d\'achat conservée, la taxe forfaitaire s\'applique automatiquement, même en cas de perte.',
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
      GlossaryTerm(term: 'Blockchain', definition: 'Technologie de registre distribué et sécurisé.'),
      GlossaryTerm(term: 'Bitcoin', definition: 'Première cryptomonnaie, utilisée comme réserve de valeur et moyen de paiement.'),
      GlossaryTerm(term: 'Ethereum', definition: 'Plateforme blockchain permettant la création de contrats intelligents et d\'applications décentralisées.'),
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
      GlossaryTerm(term: 'Token', definition: 'Unité de valeur émise sur une blockchain, représentant un actif ou un droit.'),
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
      GlossaryTerm(term: 'Plus-value', definition: 'Gain réalisé lors de la vente d\'un actif, imposable selon la législation en vigueur.'),
    ],
    takeaway: 'Bien documenter ses transactions pour une déclaration fiscale correcte.',
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
      GlossaryTerm(term: 'Rendement brut', definition: 'Loyers annuels rapportés au prix d\'achat, avant charges.'),
      GlossaryTerm(term: 'Vacance locative', definition: 'Période durant laquelle un bien reste inoccupé entre deux locataires.'),
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
      GlossaryTerm(term: 'SCPI', definition: 'Société civile qui collecte de l\'épargne pour investir et gérer un parc immobilier locatif.'),
      GlossaryTerm(term: 'Taux de distribution', definition: 'Revenu versé aux porteurs de parts, rapporté au prix de la part.'),
    ],
  ),
  AcademyStep(
    id: 'formation_immo_levier',
    title: 'L\'effet de levier du crédit',
    level: AcademyLevel.avance,
    tagline: 'Investir avec l\'argent de la banque pour démultiplier son capital engagé.',
    bullets: [
      'Emprunter pour investir permet d\'acquérir un bien plus important que son épargne seule.',
      'Le levier amplifie les gains... mais aussi les pertes potentielles.',
      'Le coût du crédit doit rester inférieur au rendement espéré du bien.',
    ],
    vocabulary: [
      GlossaryTerm(term: 'Effet de levier', definition: 'Utiliser l\'emprunt pour démultiplier la capacité d\'investissement au-delà de son épargne propre.'),
      GlossaryTerm(term: 'Taux d\'endettement', definition: 'Part des revenus consacrée au remboursement de crédits, encadrée par les banques.'),
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
      GlossaryTerm(term: 'Micro-foncier', definition: 'Régime fiscal simplifié avec abattement forfaitaire de 30 % sur les loyers d\'un bien loué nu.'),
      GlossaryTerm(term: 'LMNP', definition: 'Loueur en Meublé Non Professionnel : statut fiscal pour la location meublée, avec amortissement possible.'),
      GlossaryTerm(term: 'Amortissement', definition: 'Constatation comptable de la perte de valeur d\'un bien dans le temps, déductible du revenu imposable.'),
    ],
    takeaway: 'Le régime fiscal choisi peut faire varier du simple au double l\'impôt payé sur les mêmes loyers.',
  ),
];

const _comptesSteps = [
  AcademyStep(
    id: 'formation_comptes_bilan',
    title: 'Le bilan comptable',
    level: AcademyLevel.avance,
    tagline: 'Une photo du patrimoine de l\'entreprise à un instant donné.',
    bullets: [
      'L\'actif liste ce que l\'entreprise possède (biens, créances, trésorerie).',
      'Le passif liste comment c\'est financé (dettes et fonds propres).',
      'Actif total = Passif total, toujours : c\'est l\'équilibre fondamental du bilan.',
    ],
    vocabulary: [
      GlossaryTerm(term: 'Actif', definition: 'Ce que possède l\'entreprise : immobilisations, stocks, créances, trésorerie.'),
      GlossaryTerm(term: 'Passif', definition: 'La façon dont l\'actif est financé : dettes envers des tiers et fonds propres.'),
      GlossaryTerm(term: 'Fonds propres', definition: 'Ressources appartenant aux actionnaires : capital apporté et bénéfices non distribués.'),
      GlossaryTerm(term: 'Immobilisations', definition: 'Biens durables détenus par l\'entreprise (locaux, machines, brevets...).'),
    ],
  ),
  AcademyStep(
    id: 'formation_comptes_resultat',
    title: 'Le compte de résultat',
    level: AcademyLevel.avance,
    tagline: 'Le film de l\'activité de l\'entreprise sur une période.',
    bullets: [
      'Chiffre d\'affaires moins les charges (achats, salaires, impôts...) donne le résultat net.',
      'Un résultat positif = bénéfice, négatif = perte.',
      'Il montre la rentabilité de l\'activité, pas nécessairement la trésorerie réellement disponible.',
    ],
    vocabulary: [
      GlossaryTerm(term: 'Chiffre d\'affaires', definition: 'Total des ventes de biens ou services réalisées sur la période.'),
      GlossaryTerm(term: 'Charges', definition: 'Ensemble des dépenses engagées pour faire fonctionner l\'entreprise.'),
      GlossaryTerm(term: 'Résultat net', definition: 'Ce qu\'il reste du chiffre d\'affaires une fois toutes les charges et impôts déduits.'),
      GlossaryTerm(term: 'EBITDA', definition: 'Excédent brut d\'exploitation : résultat avant intérêts, impôts et amortissements, reflète la rentabilité opérationnelle pure.'),
    ],
  ),
  AcademyStep(
    id: 'formation_comptes_cashflow',
    title: 'Le cash-flow',
    level: AcademyLevel.avance,
    tagline: 'L\'argent qui entre et sort vraiment des caisses.',
    bullets: [
      'Une entreprise peut être bénéficiaire sur le papier et manquer de trésorerie.',
      'Le free cash-flow est ce qu\'il reste après avoir financé l\'activité et les investissements.',
      'C\'est souvent l\'indicateur le plus surveillé par les investisseurs long terme.',
    ],
    vocabulary: [
      GlossaryTerm(term: 'Trésorerie', definition: 'Argent réellement disponible sur les comptes de l\'entreprise à un instant donné.'),
      GlossaryTerm(term: 'Free cash-flow', definition: 'Trésorerie générée par l\'activité, après financement des investissements nécessaires.'),
      GlossaryTerm(term: 'BFR', definition: 'Besoin en fonds de roulement : argent nécessaire pour financer le décalage entre dépenses et encaissements.'),
    ],
    takeaway: 'Un bénéfice comptable ne garantit jamais qu\'il y ait de l\'argent disponible en caisse : toujours regarder aussi le cash-flow.',
  ),
  AcademyStep(
    id: 'formation_comptes_ratios',
    title: 'Les ratios financiers clés',
    level: AcademyLevel.avance,
    tagline: 'Des repères pour comparer des entreprises entre elles rapidement.',
    bullets: [
      'La marge nette mesure la part du chiffre d\'affaires transformée en bénéfice.',
      'Le ROE mesure la rentabilité des capitaux apportés par les actionnaires.',
      'Le ratio d\'endettement compare les dettes aux fonds propres pour juger la solidité financière.',
    ],
    vocabulary: [
      GlossaryTerm(term: 'Marge nette', definition: 'Résultat net rapporté au chiffre d\'affaires, en %.'),
      GlossaryTerm(term: 'ROE', definition: 'Return on Equity : résultat net rapporté aux fonds propres, mesure la rentabilité pour les actionnaires.'),
      GlossaryTerm(term: 'Ratio d\'endettement', definition: 'Dettes financières rapportées aux fonds propres : plus il est élevé, plus l\'entreprise dépend de l\'emprunt.'),
      GlossaryTerm(
        term: 'PER (Price Earning Ratio)',
        definition: 'Prix de l\'action rapporté au bénéfice par action ; à ne pas confondre avec le Plan Épargne Retraite (même sigle, sens différent).',
      ),
    ],
    takeaway: 'Un seul ratio ne suffit jamais : c\'est leur combinaison qui donne une image fidèle de la santé d\'une entreprise.',
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
    id: 'formation_comptes',
    title: 'Lire les comptes d\'une entreprise',
    description: 'Bilan, compte de résultat, cash-flow et ratios clés.',
    icon: LucideIcons.fileSpreadsheet,
    steps: _comptesSteps,
  ),
];
