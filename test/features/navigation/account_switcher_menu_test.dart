import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/profiles/profile_controller.dart';
import 'package:opime/core/profiles/profile_repository.dart';
import 'package:opime/core/storage/vault_folder_service.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:opime/features/navigation/account_switcher_menu.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:shared_preferences/shared_preferences.dart';

/// Le menu du sélecteur de compte (`openAccountSwitcherMenu`) affiche
/// maintenant, au-dessus de la liste des profils, une ligne flèches
/// gauche/droite pour basculer entre les vaults enregistrés (voir
/// `VaultFolderService`) — pas de liste par nom ici, volontairement (elle
/// reste dans Réglages). Ces tests couvrent cet ajout sans passer par le
/// sélecteur de dossier natif (voir `vault_folder_service_test.dart` pour
/// le seeding direct des préférences déjà établi pour ça).
void main() {
  late Directory profileDir;
  late Directory vaultADir;
  late Directory vaultBDir;
  late ProfileController profileController;
  late VaultFolderService vaultFolderService;

  Map<String, dynamic> vaultJson({
    required String id,
    required String name,
    required String path,
  }) => {
    'id': id,
    'name': name,
    'vaultPath': path,
    'bookmarkData': null,
    'bookmarkTargetsVault': false,
  };

  setUp(() async {
    profileDir = await Directory.systemTemp.createTemp('opime_switcher_profile_');
    vaultADir = await Directory.systemTemp.createTemp('opime_switcher_vault_a_');
    vaultBDir = await Directory.systemTemp.createTemp('opime_switcher_vault_b_');
    SharedPreferences.setMockInitialValues({
      'saved_vaults_json': jsonEncode([
        vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        vaultJson(id: 'b', name: 'Vault B', path: vaultBDir.path),
      ]),
      'active_vault_id': 'a',
    });
    profileController = ProfileController(ProfileRepository(profileDir.path));
    await profileController.load();
    vaultFolderService = VaultFolderService();
  });

  tearDown(() async {
    profileController.dispose();
    for (final dir in [profileDir, vaultADir, vaultBDir]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  Finder findIconButton(IconData icon) => find.byWidgetPredicate((widget) {
    if (widget is! IconButton) return false;
    final child = widget.icon;
    return child is Icon && child.icon == icon;
  });

  bool isEnabled(WidgetTester tester, Finder finder) =>
      tester.widget<IconButton>(finder).onPressed != null;

  Future<void> pumpMenu(
    WidgetTester tester, {
    required Future<void> Function(String path) onVaultActivated,
    VoidCallback? onNoVaultSelected,
  }) async {
    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          shadcnLocalizationsFrDelegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: Scaffold(
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () => openAccountSwitcherMenu(
                context,
                profileController: profileController,
                onSelect: (_) {},
                vaultFolderService: vaultFolderService,
                onVaultActivated: onVaultActivated,
                onNoVaultSelected: onNoVaultSelected ?? () {},
              ),
              child: const shadcn.Text('OPEN'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    // Le chargement des vaults (listVaults/getActiveVault) est async :
    // attendre qu'il se résolve avant d'inspecter le menu.
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (find.text('Vault A').evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  testWidgets(
    'affiche le nom du vault actif avec des flèches gauche/droite, sans '
    'liste de vaults par nom ni bouton d\'ajout (ça reste dans Réglages)',
    (tester) async {
      await pumpMenu(tester, onVaultActivated: (_) async {});

      expect(find.text('Vault A'), findsOneWidget);
      expect(findIconButton(LucideIcons.chevronLeft), findsOneWidget);
      expect(findIconButton(LucideIcons.chevronRight), findsOneWidget);
      expect(find.text('Coffres-forts'), findsNothing);
      expect(find.text('Ajouter un coffre-fort'), findsNothing);
    },
  );

  testWidgets(
    'un seul vault enregistré : les flèches sont visibles mais désactivées',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_vaults_json': jsonEncode([
          vaultJson(id: 'a', name: 'Vault A', path: vaultADir.path),
        ]),
        'active_vault_id': 'a',
      });
      await pumpMenu(tester, onVaultActivated: (_) async {});

      expect(isEnabled(tester, findIconButton(LucideIcons.chevronLeft)), isFalse);
      expect(isEnabled(tester, findIconButton(LucideIcons.chevronRight)), isFalse);
    },
  );

  // La bascule elle-même (tap flèche → `closeOverlay` → `setActiveVault` →
  // `onVaultActivated`) n'est volontairement pas testée ici en pilotant ce
  // menu déroulant : attendre la résolution du vrai `dart:io`/
  // `shared_preferences` sous-jacent via `tester.runAsync` s'est révélée
  // ponctuellement très lente à se résoudre dans cet environnement, de
  // façon non déterministique (observé jusqu'à plusieurs minutes sur une
  // exécution isolée alors qu'une autre passe en une seconde), sans lien
  // avec la logique testée elle-même — `VaultFolderService.setActiveVault`
  // est déjà couvert par `vault_folder_service_test.dart`, et
  // `_switchVault` ne fait qu'enchaîner cet appel avec `onVaultActivated`/
  // `onNoVaultSelected`, visible à la lecture du code.
}
