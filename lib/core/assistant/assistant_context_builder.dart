import '../../features/budget/budget_repository.dart';
import '../../features/budget/budget_tracking_models.dart';
import '../../features/budget/budget_tracking_repository.dart';
import '../../features/investments/investments_models.dart';
import '../../features/investments/investments_repository.dart';
import '../../features/investments/performance_calculator.dart';
import '../../features/strategy/strategy_repository.dart';
import '../../core/money_format.dart' show formatEuros;
import '../../core/simulations/simulation_state_repository.dart';

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

  /// Synthèse complète du profil : investissements, budget (prévisionnel
  /// puis suivi mensuel réel), notes de stratégie et simulations.
  Future<String> buildPatrimoineContext() async {
    final sections = <String>[
      '## Synthèse du patrimoine',
      await _buildInvestmentsSection(),
      await _buildBudgetSection(),
      await _buildBudgetTrackingSection(),
      await _buildStrategySection(),
      await _buildSimulationsSection(),
    ];
    return sections.join('\n\n');
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
        // Un investissement exclu du patrimoine (voir
        // Investment.excludedFromPatrimoine) compte quand même ici : cette
        // exclusion ne porte que sur les agrégats globaux du Dashboard
        // ("Patrimoine net/brut", carte Allocation) — voir l'annotation
        // `excludedText` plus bas, qui prévient l'assistant de cette nuance
        // plutôt que de fausser ses propres totaux.
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
        final mwrText = mwr == null
            ? ''
            : ', rendement ${_percent(mwr.rate)} ${mwr.annualized ? '/ an' : 'depuis le début'}';
        final gainText = investment.unrealizedGain == null
            ? ''
            : ', plus-value ${formatEuros(gain)} (${_percent(invested == 0 ? 0 : gain / invested)})';
        final transactions = investment.transactions;
        final txnInfo = transactions.isEmpty
            ? 'aucune transaction'
            : '${transactions.length} transaction(s) '
                  '(${_formatDate(transactions.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b))} → '
                  '${_formatDate(transactions.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b))})';
        final lastPrice = investment.lastPrice;
        final lastPriceText = lastPrice == null
            ? ''
            : ', dernier cours '
                  '${formatEuros(lastPrice * (investment.lastFxRateToEur ?? 1.0))}';
        final excludedText = investment.excludedFromPatrimoine
            ? ' [exclu par l\'utilisateur du "Patrimoine net/brut" et de '
                  'l\'allocation affichés sur le tableau de bord]'
            : '';
        lines.add(
          '- ${investment.label} (${investment.isin}) — ${effectiveClass.label}'
          ', quantité ${_formatQuantity(investment.quantityHeld)}, '
          'PRU ${formatEuros(investment.pru)}'
          '$lastPriceText, '
          'valeur ${formatEuros(value)}$gainText$mwrText, $txnInfo$excludedText',
        );
      }
    }

    // Répartition par classe d'actif (la valeur d'une classe est la somme
    // de ses investissements, quelle que soit la classe du compte porteur).
    final allocation = [
      for (final entry in perClass.entries)
        '- ${entry.key.label} : ${formatEuros(entry.value)}'
            ' (${totalValue == 0 ? '0' : _percent(entry.value / totalValue)})',
    ].join('\n');

    return [
      'Total valorisé : ${formatEuros(totalValue)}',
      'Total investi : ${formatEuros(totalInvested)}',
      'Plus-value latente totale : ${formatEuros(totalGain)}',
      'Répartition par classe d\'actif :',
      allocation,
      ...lines,
    ].join('\n');
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
          ' : réalité ${formatEuros(item.realite)}'
          '${item.budget != 0 ? ', budget ${formatEuros(item.budget)}' : ''}',
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

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(2)} %';

  String _formatQuantity(double q) {
    final abs = q.abs();
    if (abs == 0) return '0';
    if (abs >= 1000) return q.toStringAsFixed(0);
    if (abs >= 1) return q.toStringAsFixed(2);
    return q.toStringAsFixed(4);
  }
}
