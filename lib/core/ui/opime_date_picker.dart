import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../date_format.dart';

/// Remplace `DatePicker` de shadcn_flutter — le paquet code en dur une
/// grille de calendrier qui commence la semaine le dimanche (voir
/// `CalendarGridData` dans son code source, `firstDayOfMonth.weekday` utilisé
/// tel quel sans notion de premier jour configurable) et un format de date
/// anglo-saxon ("April 24, 2026", voir l'extension `formatDateTime` — un
/// gabarit figé, non personnalisable même via une locale différente). Ce
/// widget reprend le champ/bouton déclencheur et la boîte de dialogue de
/// `ObjectFormField` (mêmes apparence et comportement que l'ancien
/// `DatePicker`, aucune régression visuelle) mais fournit sa propre grille —
/// [OpimeCalendarGrid], semaine lundi → dimanche — et son propre format de
/// libellé ([formatDateFrLong], "24 avril 2026").
class OpimeDatePicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final Widget? placeholder;

  const OpimeDatePicker({
    super.key,
    required this.value,
    this.onChanged,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return ObjectFormField<DateTime>(
      value: value,
      onChanged: onChanged,
      placeholder: placeholder ?? const shadcn.Text('Choisir une date'),
      trailing: const Icon(LucideIcons.calendarDays),
      builder: (context, date) => shadcn.Text(formatDateFrLong(date)),
      editorBuilder: (context, handler) => OpimeCalendarGrid(
        value: handler.value,
        onSelected: (date) => handler.value = date,
      ),
    );
  }
}

/// Les trois niveaux de zoom du calendrier — voir [_OpimeCalendarGridState.header].
/// Cliquer l'en-tête remonte d'un niveau ([_OpimeCalendarGridState._zoomOut]) :
/// jour → mois → année, jamais plus haut. Choisir un mois ou une année
/// redescend d'un niveau vers le jour, comme le sélecteur de shadcn_flutter
/// (voir `Calendar`'s propre `CalendarViewType` dans son code source) —
/// pratique pour atteindre rapidement une date éloignée sans cliquer
/// "mois précédent" des dizaines de fois.
enum _ViewType { day, month, year }

/// Nombre d'années affichées d'un coup dans la vue année ([_ViewType.year])
/// — une grille 3×4, comme la vue mois.
const _yearsPerPage = 12;

/// Grille de calendrier, semaine lundi → dimanche en vue jour, avec
/// navigation mois/année précédent-suivant et remontée jour → mois → année
/// en cliquant l'en-tête — voir [OpimeDatePicker], qui l'utilise comme
/// contenu de sa boîte de dialogue de sélection.
class OpimeCalendarGrid extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onSelected;

  const OpimeCalendarGrid({
    super.key,
    required this.value,
    required this.onSelected,
  });

  @override
  State<OpimeCalendarGrid> createState() => _OpimeCalendarGridState();
}

class _OpimeCalendarGridState extends State<OpimeCalendarGrid> {
  static const _weekdayLabels = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

  late int _year;
  late int _month;
  _ViewType _viewType = _ViewType.day;

  /// Première année de la page affichée en vue année ([_ViewType.year]) —
  /// indépendante de [_year] (qui reste l'année réellement survolée/choisie)
  /// pour permettre de naviguer par page de [_yearsPerPage] ans sans perdre
  /// la position en cours de route.
  late int _yearRangeStart;

  @override
  void initState() {
    super.initState();
    // Le mois affiché à l'ouverture est celui de la date déjà sélectionnée
    // s'il y en a une, sinon le mois courant — jamais réinitialisé tant que
    // ce widget reste monté (une sélection dans le même mois ne doit pas
    // faire sauter la vue).
    final anchor = widget.value ?? DateTime.now();
    _year = anchor.year;
    _month = anchor.month;
    _yearRangeStart = (_year ~/ _yearsPerPage) * _yearsPerPage;
  }

  /// Bouton précédent/suivant de l'en-tête — son unité dépend du niveau de
  /// zoom courant (mois en vue jour, année en vue mois, page de
  /// [_yearsPerPage] ans en vue année).
  void _step(int delta) {
    setState(() {
      switch (_viewType) {
        case _ViewType.day:
          final total = _year * 12 + (_month - 1) + delta;
          _year = total ~/ 12;
          _month = total % 12 + 1;
        case _ViewType.month:
          _year += delta;
        case _ViewType.year:
          _yearRangeStart += delta * _yearsPerPage;
      }
    });
  }

  /// Clic sur l'en-tête : remonte d'un niveau de zoom (jour → mois →
  /// année), jamais au-delà de la vue année.
  void _zoomOut() {
    setState(() {
      switch (_viewType) {
        case _ViewType.day:
          _viewType = _ViewType.month;
        case _ViewType.month:
          _yearRangeStart = (_year ~/ _yearsPerPage) * _yearsPerPage;
          _viewType = _ViewType.year;
        case _ViewType.year:
          break;
      }
    });
  }

  void _pickMonth(int month) {
    setState(() {
      _month = month;
      _viewType = _ViewType.day;
    });
  }

  void _pickYear(int year) {
    setState(() {
      _year = year;
      _viewType = _ViewType.month;
    });
  }

  /// Jours affichés dans la grille (mois courant + jours des mois
  /// voisins nécessaires pour compléter des semaines entières commençant le
  /// lundi) — 35 ou 42 jours selon le mois, toujours un multiple de 7.
  List<DateTime> _gridDays() {
    final firstOfMonth = DateTime(_year, _month, 1);
    // `DateTime.weekday` vaut 1 (lundi) à 7 (dimanche) : le nombre de jours
    // à remonter avant le 1er pour tomber sur le lundi qui débute sa
    // semaine est donc `weekday - 1`, jamais `weekday` seul (qui donnerait
    // un calage dimanche → premier jour, voir la doc de tête du fichier).
    final leading = (firstOfMonth.weekday - DateTime.monday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leading));
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final totalCells = leading + daysInMonth;
    final trailing = (7 - totalCells % 7) % 7;
    final totalDays = totalCells + trailing;
    return List.generate(totalDays, (i) => gridStart.add(Duration(days: i)));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String get _headerLabel {
    switch (_viewType) {
      case _ViewType.day:
        final monthLabel = frenchMonths[_month - 1];
        // Majuscule initiale du mois : en tête de la barre de navigation,
        // pas au fil d'une phrase (contrairement à `formatDateFrLong`, qui
        // reste tout en minuscules).
        return '${monthLabel[0].toUpperCase()}${monthLabel.substring(1)} $_year';
      case _ViewType.month:
        return '$_year';
      case _ViewType.year:
        return '$_yearRangeStart – ${_yearRangeStart + _yearsPerPage - 1}';
    }
  }

  Widget _buildDayGrid() {
    final today = DateTime.now();
    final selected = widget.value;
    final days = _gridDays();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(child: shadcn.Text(label).muted().xSmall()),
              ),
          ],
        ),
        for (var week = 0; week < days.length ~/ 7; week++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _PickerCell(
                    label: '${days[week * 7 + i].day}',
                    dimmed: days[week * 7 + i].month != _month,
                    isCurrent: _isSameDay(days[week * 7 + i], today),
                    isSelected:
                        selected != null &&
                        _isSameDay(days[week * 7 + i], selected),
                    onTap: () => widget.onSelected(days[week * 7 + i]),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    final today = DateTime.now();
    final selected = widget.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++)
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                Builder(
                  builder: (context) {
                    final month = row * 3 + col + 1;
                    final label = frenchMonths[month - 1];
                    return Expanded(
                      child: _PickerCell(
                        // Nom complet, pas une abréviation à 3 lettres :
                        // "juin"/"juillet" partageraient la même ("Jui"),
                        // ambiguë.
                        label: '${label[0].toUpperCase()}${label.substring(1)}',
                        dimmed: false,
                        isCurrent: _year == today.year && month == today.month,
                        isSelected:
                            selected != null &&
                            selected.year == _year &&
                            selected.month == month,
                        onTap: () => _pickMonth(month),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildYearGrid() {
    final today = DateTime.now();
    final selected = widget.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++)
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                Builder(
                  builder: (context) {
                    final year = _yearRangeStart + row * 3 + col;
                    return Expanded(
                      child: _PickerCell(
                        label: '$year',
                        dimmed: false,
                        isCurrent: year == today.year,
                        isSelected: selected != null && selected.year == year,
                        onTap: () => _pickYear(year),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.ghost(
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
                onPressed: () => _step(-1),
              ),
              Expanded(
                child: GhostButton(
                  // Vue année : rien de plus haut à remonter, le clic sur
                  // l'en-tête reste donc sans effet.
                  enabled: _viewType != _ViewType.year,
                  onPressed: _zoomOut,
                  child: shadcn.Text(_headerLabel).medium().center(),
                ),
              ),
              IconButton.ghost(
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                onPressed: () => _step(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          switch (_viewType) {
            _ViewType.day => _buildDayGrid(),
            _ViewType.month => _buildMonthGrid(),
            _ViewType.year => _buildYearGrid(),
          },
        ],
      ),
    );
  }
}

/// Case cliquable d'une grille de calendrier — jour, mois ou année selon le
/// niveau de zoom (voir [_OpimeCalendarGridState]) : même apparence aux
/// trois niveaux, seul [label] change.
class _PickerCell extends StatelessWidget {
  final String label;

  /// `true` pour un jour d'un mois voisin (affiché pour compléter la
  /// grille) — sans équivalent en vue mois/année, toujours `false` là.
  final bool dimmed;

  /// `true` pour aujourd'hui (vue jour), le mois courant (vue mois) ou
  /// l'année courante (vue année).
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerCell({
    required this.label,
    required this.dimmed,
    required this.isCurrent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isSelected
        ? theme.colorScheme.primaryForeground
        : dimmed
        ? theme.colorScheme.mutedForeground
        : theme.colorScheme.foreground;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary : null,
              borderRadius: theme.borderRadiusSm,
              border: isCurrent && !isSelected
                  ? Border.all(color: theme.colorScheme.primary)
                  : null,
            ),
            child: shadcn.Text(
              label,
              style: TextStyle(color: foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ).small(),
          ),
        ),
      ),
    );
  }
}
