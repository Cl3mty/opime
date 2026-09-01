import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:shared_preferences/shared_preferences.dart';
import 'investments_models.dart';
import 'investments_repository.dart';
import 'patrimoine_refresh_controller.dart';

/// Fenêtre de remontée d'un rappel — une date « approche » dès qu'elle
/// tombe dans les [kReminderWindow] jours à venir, et reste affichée
/// au-delà (déjà passée, non explicitement masquée) : contrairement à
/// [NotificationsController] (actualités/alertes crypto, expiration à 7
/// jours), un jalon fiscal ou une échéance d'exercice reste pertinent tant
/// que l'utilisateur ne l'a pas vu.
const kReminderWindow = Duration(days: 60);

/// Un rappel individuel à afficher dans [ReminderBanner] — soit un jalon
/// fiscal de compte ([FiscalMilestoneKind.avantageFiscal], PEA/assurance
/// vie), soit une échéance d'exercice BSPCE/stock-options
/// ([Investment.exerciseDeadline]).
class InvestmentReminder {
  final String entityId;
  final DateTime date;
  final String message;

  const InvestmentReminder({
    required this.entityId,
    required this.date,
    required this.message,
  });

  /// Clé `shared_preferences` d'un masquage — paramétrée par entité ET par
  /// date : si la date change (ex. modification de `openingDate`), le
  /// rappel redevient visible plutôt que de rester masqué à tort pour une
  /// occurrence différente.
  String get dismissKey =>
      'dismissed_reminder:$entityId:${date.toIso8601String()}';
}

/// Calcule les rappels à remonter pour [accounts] à la date [now] — jalon
/// fiscal de compte ([accountFiscalMilestone]) et échéance d'exercice BSPCE
/// d'une position Private Equity [PrivateEquityKind.actionsSalarie], toutes
/// deux dans la fenêtre [kReminderWindow]. Fonction pure (aucune E/S,
/// aucun filtrage de masquage — voir [filterDismissedReminders]) : le cœur
/// testable de [ReminderBanner], séparé de son scan asynchrone
/// (repository + shared_preferences) pour rester testable sans harnais de
/// widget. Triés par date croissante.
List<InvestmentReminder> computeReminders({
  required List<InvestmentAccount> accounts,
  required DateTime now,
}) {
  final upcoming = <InvestmentReminder>[];
  for (final account in accounts) {
    final milestone = accountFiscalMilestone(
      envelope: account.envelope,
      openingDate: account.openingDate,
      today: now,
    );
    if (milestone != null && _isWithinWindow(milestone.date, now)) {
      upcoming.add(
        InvestmentReminder(
          entityId: account.id,
          date: milestone.date,
          message:
              'Avantage fiscal « ${account.name} » atteint le '
              '${_formatDate(milestone.date)}',
        ),
      );
    }
    for (final investment in account.investments) {
      final deadline = investment.exerciseDeadline;
      if (investment.privateEquityKind == PrivateEquityKind.actionsSalarie &&
          deadline != null &&
          _isWithinWindow(deadline, now)) {
        upcoming.add(
          InvestmentReminder(
            entityId: investment.id,
            date: deadline,
            message:
                'Échéance d\'exercice BSPCE « ${investment.label} » le '
                '${_formatDate(deadline)}',
          ),
        );
      }
    }
  }
  return upcoming..sort((a, b) => a.date.compareTo(b.date));
}

/// Retire de [reminders] ceux déjà masqués selon [isDismissed] (typiquement
/// `prefs.getBool(r.dismissKey) ?? false`) — fonction pure, séparée pour
/// être testable sans `shared_preferences` réel.
List<InvestmentReminder> filterDismissedReminders(
  List<InvestmentReminder> reminders, {
  required bool Function(String dismissKey) isDismissed,
}) => [
  for (final reminder in reminders)
    if (!isDismissed(reminder.dismissKey)) reminder,
];

bool _isWithinWindow(DateTime date, DateTime now) =>
    date.isBefore(now.add(kReminderWindow));

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Bandeau global affiché quand un compte approche/atteint un jalon fiscal
/// ([accountFiscalMilestone] — PEA à 5 ans, assurance vie à 8 ans) ou qu'un
/// Private Equity [PrivateEquityKind.actionsSalarie] approche/dépasse son
/// [Investment.exerciseDeadline] (BSPCE/stock-options) — les deux sont
/// aujourd'hui purement passifs (affichés seulement si l'utilisateur ouvre
/// la fiche compte/position concernée) ; ce bandeau les remonte
/// proactivement, même principe que `UpdateBanner`
/// (`core/updates/update_banner.dart`) mais pour plusieurs rappels
/// simultanés (une ligne par rappel, chacun avec son propre bouton de
/// fermeture, plutôt qu'un unique dismiss global). La décision de quoi
/// afficher est déléguée à [computeReminders]/[filterDismissedReminders]
/// (fonctions pures, testées indépendamment) — ce widget ne fait que le
/// scan asynchrone (repository + shared_preferences) et le rendu.
class ReminderBanner extends StatefulWidget {
  final String vaultPath;
  final PatrimoineRefreshController refreshSignal;
  final Widget child;

  const ReminderBanner({
    super.key,
    required this.vaultPath,
    required this.refreshSignal,
    required this.child,
  });

  @override
  State<ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<ReminderBanner> {
  List<InvestmentReminder> _reminders = const [];

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_scan);
    _scan();
  }

  @override
  void didUpdateWidget(covariant ReminderBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal.removeListener(_scan);
      widget.refreshSignal.addListener(_scan);
    }
    if (oldWidget.vaultPath != widget.vaultPath) _scan();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_scan);
    super.dispose();
  }

  Future<void> _scan() async {
    final accounts = await InvestmentsRepository(widget.vaultPath).listAll();
    final upcoming = computeReminders(
      accounts: accounts,
      now: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    final visible = filterDismissedReminders(
      upcoming,
      isDismissed: (key) => prefs.getBool(key) ?? false,
    );
    if (mounted) setState(() => _reminders = visible);
  }

  Future<void> _dismiss(InvestmentReminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reminder.dismissKey, true);
    if (mounted) {
      setState(
        () => _reminders = _reminders.where((r) => r != reminder).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reminders.isEmpty) return widget.child;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: accent.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final reminder in _reminders)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bell, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Expanded(child: shadcn.Text(reminder.message)),
                      IconButton.ghost(
                        icon: const Icon(LucideIcons.x, size: 14),
                        onPressed: () => _dismiss(reminder),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
