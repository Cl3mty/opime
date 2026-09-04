import '../../features/budget/budget_repository.dart';
import '../../features/budget/budget_tracking_models.dart';
import '../../features/budget/budget_tracking_repository.dart';
import '../../features/investments/investments_models.dart';
import '../../features/investments/investments_repository.dart';
import '../../features/investments/performance_calculator.dart';
import '../../features/strategy/strategy_repository.dart';
import '../../core/money_format.dart' show formatEuros, formatEurosCompact;
import '../../core/simulations/simulation_state_repository.dart';

/// Sections du contexte patrimoine, chacune activable indépendamment
/// via le filtrage par mots-clés (voir [AssistantContextBuilder]).
enum _ContextSection {
  investments,
  budget,
  budgetTracking,
  strategy,
  simulations,
}

/// Construit une synthèse texte (en français) des données du profil actif,
/// destinée au contexte de l'assistant IA.
///
/// Tout reste local : les données sont lues depuis les repositories du
/// profil puis insérées dans le prompt envoyé à l'instance Ollama. Rien
/// n'est envoyé vers un service en ligne.
class AssistantContextBuilder {
  final String vaultPath;

  AssistantContextBuilder(this.vaultPath);

  /// Clés des états de simulation persistés par les écrans
  /// (`simulations_*_screen.dart`) — lues telles quelles pour donner au
  /// modèle une vision des paramètres de simulation saisis.
  static const _simulationKeys = [
    'wealth',
    'wealth_simple',
    'wealth_monte_carlo',
    'loan',
    'taxation',
    'taxation_ifi',
    'taxation_ir',
    'transmission',
    'transmission_demembrement',
    'transmission_donation',
    'transmission_heritage',
  ];

  /// Mots-clés par section : quand [buildPatrimoineContext] reçoit une
  /// question, seules les sections dont un mot-clé apparaît dans la question
  /// (insensible à la casse) sont incluses. Sans correspondance, toutes les
  /// sections sont envoyées (comportement d'origine).
  static const _sectionKeywords = {
    _ContextSection.investments: [
      'investissement', 'placement', 'pea', 'cto', 'compte-titre',
      'actions', 'obligations', 'etf', 'fonds', 'valorisation',
      'plus-value', 'performance', 'allocation', 'patrimoine', 'isin',
      'rendement', 'portefeuille', 'actif', 'classe d\'actif',
      'pru', 'cours', 'quantité', 'marché', 'bourse',
    ],
    _ContextSection.budget: [
      'budget', 'dépense', 'dépenses', 'revenu', 'revenus', 'épargne',
      'solde', 'poste', 'catégorie', 'facture', 'factures',
      'charges', 'prélèvement', 'salaire', 'loyer', 'impot', 'impôts',
    ],
    _ContextSection.budgetTracking: [
      'suivi', 'réel', 'réalité', 'constaté', 'historique',
      'mois', 'amazon', 'abonnement', 'mensuel', 'chronique',
      'régulier', 'habituel', 'dépense nommée',
    ],
    _ContextSection.strategy: [
      'stratégie', 'strategie', 'note', 'plan', 'objectif', 'objectifs',
      'projet', 'projets', 'feuille de route', 'diagnostic',
    ],
    _ContextSection.simulations: [
      'simulation', 'scénario', 'scenario', 'projection', 'crédit',
      'credit', 'prêt', 'pret', 'ifi', 'impôt', 'impots', 'ir',
      'quotient', 'familial', 'transmission', 'démembrement',
      'demembrement', 'donation', 'héritage', 'heritage', 'succession',
      'wealth', 'patrimoine net',
    ],
  };

  /// Longueurs maximales, pour garder le contexte raisonnable (et donc la
  /// consommation mémoire/tokens du modèle) même avec beaucoup de données.
  static const _maxStrategyNotes = 3;
  static const _maxNoteChars = 1500;
  static const _maxSimulationChars = 2500;

  /// Nombre de mois de Suivi budgétaire remontés (voir
  /// [_buildBudgetTrackingSection]) — un an, pour couvrir un "résumé
  /// annuel" typique sans faire exploser la taille du contexte.
  static const _maxTrackingMonths = 12;
  static const _maxBudgetTrackingChars = 4000;

  /// Synthèse du profil : investissements, budget, suivi, stratégie et
  /// simulations.
  ///
  /// Quand [question] est fourni, seules les sections dont un mot-clé
  /// apparaît dans la question sont incluses — les autres sont omises pour
  /// réduire la consommation de tokens. Les totaux investissements (3 lignes
  /// de résumé) sont toujours inclus comme vue d'ensemble. Sans question ou
  /// sans correspondance, toutes les sections sont envoyées.
  Future<String> buildPatrimoineContext({String? question}) async {
    final active = _activeSectionsFor(question);
    final sections = <String>['## Synthèse du patrimoine'];

    // Totaux investissements toujours inclus comme résumé rapide — même
    // quand le détail investissements n'est pas pertinent, ces 3 lignes
    // donnent au modèle une vue d'ensemble du patrimoine.
    final totals = await _buildInvestmentsSummary();
    if (totals != null) sections.add(totals);

    if (active.contains(_ContextSection.investments)) {
      sections.add(await _buildInvestmentsSection());
    }
    if (active.contains(_ContextSection.budget)) {
      sections.add(await _buildBudgetSection());
    }
    if (active.contains(_ContextSection.budgetTracking)) {
      sections.add(await _buildBudgetTrackingSection());
    }
    if (active.contains(_ContextSection.strategy)) {
      sections.add(await _buildStrategySection());
    }
    if (active.contains(_ContextSection.simulations)) {
      sections.add(await _buildSimulationsSection());
    }
    return sections.join('\n\n');
  }

  /// Détermine quelles sections inclure en fonction de la question posée.
  /// Retourne toutes les sections si [question] est `null` ou ne correspond
  /// à aucun mot-clé (conservatisme : mieux vaut trop de contexte que pas
  /// assez).
  Set<_ContextSection> _activeSectionsFor(String? question) {
    if (question == null || question.trim().isEmpty) {
      return _ContextSection.values.toSet();
    }
    final lower = question.toLowerCase();
    final matched = <_ContextSection>{};
    for (final entry in _sectionKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          matched.add(entry.key);
          break;
        }
      }
    }
    // Pas de correspondance → on garde tout (comportement d'origine) pour
    // ne jamais priver le modèle de contexte pertinent.
    if (matched.isEmpty) return _ContextSection.values.toSet();
    return matched;
  }

  Future<String> _buildInvestmentsSection() async {
    final accounts = await InvestmentsRepository(vaultPath).listAll();
    if (accounts.isEmpty) {
      return 'Aucun compte de placement n\'a encore été renseigné.';
    }

    final now = DateTime.now();
    final perClass = <AssetClass, double>{};
    var totalValue = 0.0;
    var totalInvested = 0.0;
    var totalGain = 0.0;

    final lines = <String>[];
    for (final account in accounts) {
      lines.add('### ${_accountLabel(account)}');
      if (account.investments.isEmpty) {
        lines.add('Aucun investissement.');
        continue;
      }
      for (final investment in account.investments) {
        final effectiveClass = investment.assetClass ?? account.assetClass;
        final value = investment.displayValue;
        final gain = investment.unrealizedGain ?? 0;
        final invested = investment.investedAmount;
        totalValue += value;
        totalInvested += invested;
        totalGain += gain;
        perClass.update(effectiveClass, (v) => v + value, ifAbsent: () => value);

        final mwr = investment.transactions.isEmpty
            ? null
            : calculateMwr(
                transactions: investment.transactions,
                currentValue: value,
                asOf: now,
              );
        final gainPercent = invested == 0 ? 0.0 : gain / invested;
        final gainPctText = investment.unrealizedGain == null
            ? ''
            : _percent(gainPercent);
        final mwrText = mwr == null ? '' : ' MWR ${_percent(mwr.rate)}';
        final lastPrice = investment.lastPrice;
        final lastPriceComp = lastPrice == null
            ? '?'
            : formatEurosCompact(
                lastPrice * (investment.lastFxRateToEur ?? 1.0),
              );
        final excludedText = investment.excludedFromPatrimoine
            ? ' [exclu]'
            : '';

        // Format compact : nom (ISIN) Classe: qty × PRU → cours = valeur
        // (+gainPct, MWR) — ~60% plus court que la prose verbose.
        final parts = StringBuffer(
          '- ${investment.label} (${investment.isin}) '
          '${effectiveClass.label}: '
          '${_formatQuantity(investment.quantityHeld)} × '
          '${formatEurosCompact(investment.pru)} → '
          '$lastPriceComp = '
          '${formatEurosCompact(value)}',
        );
        if (investment.unrealizedGain != null) {
          parts.write(' (=$gainPctText');
          if (mwr != null) parts.write(', $mwrText');
          parts.write(')');
        } else if (mwr != null) {
          parts.write(' (MWR ${_percent(mwr.rate)})');
        }
        parts.write(excludedText);
        lines.add(parts.toString());
      }
    }

    // Allocation en une ligne compacte : "Actions 12 k€ (50%) · Obligations 8 k€ (30%)"
    final allocationParts = [
      for (final entry in perClass.entries)
        '${entry.key.label} ${formatEurosCompact(entry.value)}'
            ' (${totalValue == 0 ? '0' : _percent(entry.value / totalValue)})',
    ];
    final allocation = allocationParts.join(' · ');

    return [
      'Total valorisé : ${formatEuros(totalValue)}'
      ' · Investi : ${formatEuros(totalInvested)}'
      ' · Plus-value : ${formatEuros(totalGain)}',
      'Allocation : $allocation',
      ...lines,
    ].join('\n');
  }

  /// Résumé ultra-compact (3 lignes) des totaux investissements — toujours
  /// inclus dans le contexte comme vue d'ensemble, même quand le détail
  /// investissements n'est pas pertinent pour la question posée. Retourne
  /// `null` s'il n'y a aucun investissement.
  Future<String?> _buildInvestmentsSummary() async {
    final accounts = await InvestmentsRepository(vaultPath).listAll();
    if (accounts.isEmpty) return null;

    var totalValue = 0.0;
    var totalInvested = 0.0;
    var totalGain = 0.0;
    for (final account in accounts) {
      for (final investment in account.investments) {
        totalValue += investment.displayValue;
        totalInvested += investment.investedAmount;
        totalGain += investment.unrealizedGain ?? 0;
      }
    }
    return 'Résumé patrimoine : '
        'valorisé ${formatEuros(totalValue)} · '
        'investi ${formatEuros(totalInvested)} · '
        'plus-value ${formatEuros(totalGain)}';
  }

  Future<String> _buildBudgetSection() async {
    final snapshots = await BudgetRepository(vaultPath).listAll();
    if (snapshots.isEmpty) {
      return 'Aucun budget n\'a encore été établi.';
    }
    final snapshot = snapshots.first;
    final data = snapshot.data;
    final out = StringBuffer('Budget le plus récent (${snapshot.displayName}) :\n');
    out.writeln(
      '- Revenus : ${formatEuros(data.totalRevenues)} · '
      'Dépenses : ${formatEuros(data.totalExpenses)} · '
      'Épargne/investissement : ${formatEuros(data.totalInvestments)} · '
      'Solde : ${formatEuros(data.balance)} · '
      'Taux d\'épargne : ${_percent(data.savingsRate / 100)} · '
      'Capacité d\'épargne : ${_percent(data.possibleSavingsRate / 100)}',
    );
    if (data.expenseCategories.isNotEmpty) {
      out.writeln('Dépenses par poste :');
      for (final category in data.expenseCategories) {
        final items = category.items
            .map((i) => '${i.name} (${formatEuros(i.amount)})')
            .join(', ');
        out.writeln(
          '- ${category.name} : ${formatEuros(category.items.fold(0, (s, i) => s + i.amount))}'
          '${items.isEmpty ? '' : ' — $items'}',
        );
      }
    }
    if (data.investmentCategories.isNotEmpty) {
      out.writeln('Investissements programmés :');
      for (final category in data.investmentCategories) {
        final items = category.items
            .map((i) => '${i.name} (${formatEuros(i.amount)})')
            .join(', ');
        out.writeln('- ${category.name} : $items');
      }
    }
    return out.toString().trimRight();
  }

  /// Suivi budgétaire mensuel réel (Suivi des budgets,
  /// `budget_tracking_screen.dart`) — distinct de [_buildBudgetSection],
  /// qui ne couvre que le budget *prévisionnel* (un modèle-type de mois,
  /// sans historique daté). C'est ici, mois par mois, que vivent les
  /// postes nommés réellement saisis (ex : une ligne "Amazon" dans
  /// Factures ou Dépenses avec son montant Réalité) — sans cette section,
  /// l'assistant ne peut répondre à aucune question portant sur une
  /// dépense nommée ou son historique dans le temps, alors que
  /// l'utilisateur les voit bien à l'écran.
  Future<String> _buildBudgetTrackingSection() async {
    final repo = BudgetTrackingRepository(vaultPath);
    final now = DateTime.now();
    final out = StringBuffer(
      'Suivi budgétaire mensuel (montants réellement constatés, '
      'par mois) :\n',
    );
    var totalChars = 0;
    var monthsIncluded = 0;

    for (var i = 0; i < _maxTrackingMonths; i++) {
      final date = DateTime(now.year, now.month - i);
      final month = await repo.load(date.year, date.month);
      if (_isEmptyTrackingMonth(month)) continue;

      final buffer = StringBuffer();
      buffer.writeln(
        '### ${date.month.toString().padLeft(2, '0')}/${date.year}',
      );
      _writeTrackingItems(buffer, 'Revenus', month.revenues);
      _writeTrackingItems(buffer, 'Factures', month.factures);
      _writeTrackingItems(buffer, 'Dépenses', month.depenses);
      _writeTrackingItems(buffer, 'Invest/Épargne', month.investEpargnes);
      _writeTrackingItems(buffer, 'Projets', month.projets);
      _writeTrackingItems(buffer, 'Dettes', month.dettes);

      final text = buffer.toString();
      if (totalChars + text.length > _maxBudgetTrackingChars) break;
      out.write(text);
      totalChars += text.length;
      monthsIncluded++;
    }

    if (monthsIncluded == 0) {
      return 'Aucun suivi budgétaire mensuel n\'a encore été renseigné.';
    }
    return out.toString().trimRight();
  }

  bool _isEmptyTrackingMonth(BudgetTrackingMonth month) =>
      month.revenues.isEmpty &&
      month.factures.isEmpty &&
      month.depenses.isEmpty &&
      month.investEpargnes.isEmpty &&
      month.projets.isEmpty &&
      month.dettes.isEmpty;

  void _writeTrackingItems(
    StringBuffer buffer,
    String label,
    List<TrackingItem> items,
  ) {
    final parts = [
      for (final item in items)
        if (item.realite != 0 || item.budget != 0)
          '${item.name.isEmpty ? '(sans nom)' : item.name}'
          '${item.category.isEmpty ? '' : ' [${item.category}]'}'
          ' ${formatEuros(item.realite)}'
          '${item.budget != 0 ? '/${formatEuros(item.budget)}' : ''}',
    ];
    if (parts.isEmpty) return;
    buffer.writeln('- $label : ${parts.join(' ; ')}');
  }

  Future<String> _buildStrategySection() async {
    final repo = StrategyRepository(vaultPath);
    final notes = await repo.listNotes();
    if (notes.isEmpty) {
      return 'Aucune note de stratégie.';
    }
    final out = StringBuffer('Notes de stratégie :\n');
    for (final note in notes.take(_maxStrategyNotes)) {
      final content = await repo.readNote(note.id);
      final trimmed = content.trim();
      final excerpt = trimmed.length > _maxNoteChars
          ? '${trimmed.substring(0, _maxNoteChars)}…'
          : trimmed;
      out.writeln('### ${note.title}');
      out.writeln(excerpt.isEmpty ? '(note vide)' : excerpt);
    }
    if (notes.length > _maxStrategyNotes) {
      out.writeln(
        '(${notes.length - _maxStrategyNotes} autre(s) note(s) non incluses.)',
      );
    }
    return out.toString().trimRight();
  }

  Future<String> _buildSimulationsSection() async {
    final repo = SimulationStateRepository(vaultPath);
    final out = StringBuffer('Simulations enregistrées :\n');
    var included = false;
    var totalChars = 0;
    for (final key in _simulationKeys) {
      final data = await repo.read(key);
      // N'inclut que les simulations réellement renseignées (les onglets
      // simplement visités ne persistent que `{'tabIndex': …}`, inutile).
      if (data.isEmpty || (data.length == 1 && data.containsKey('tabIndex'))) {
        continue;
      }
      final json = data.toString();
      final remaining = _maxSimulationChars - totalChars;
      if (remaining <= 0) break;
      out.writeln(
        '- `$key` : ${json.length > remaining ? '${json.substring(0, remaining)}…' : json}',
      );
      totalChars += json.length;
      included = true;
    }
    if (!included) return 'Aucune simulation renseignée.';
    return out.toString().trimRight();
  }

  String _accountLabel(InvestmentAccount account) {
    final buffer = StringBuffer(account.name);
    if (account.envelope != null) buffer.write(' (${account.envelope!.label})');
    if (account.bankName != null) buffer.write(' — ${account.bankName}');
    if (account.description != null &&
        account.description!.trim().isNotEmpty) {
      buffer.write(' — ${account.description!.trim()}');
    }
    if (account.excludedFromPatrimoine) {
      buffer.write(
        ' [compte exclu par l\'utilisateur du "Patrimoine net/brut" et de '
        'l\'allocation affichés sur le tableau de bord]',
      );
    }
    return buffer.toString();
  }

  String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(2)} %';

  String _formatQuantity(double q) {
    final abs = q.abs();
    if (abs == 0) return '0';
    if (abs >= 1000) return q.toStringAsFixed(0);
    if (abs >= 1) return q.toStringAsFixed(2);
    return q.toStringAsFixed(4);
  }
}
