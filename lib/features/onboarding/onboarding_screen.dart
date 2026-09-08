import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/storage/vault_folder_service.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  final VaultFolderService vaultFolderService;

  /// Rappel après création du coffre-fort : en `async` car le chargement
  /// initial des profils s'y fait — s'il échoue, l'erreur doit remonter
  /// à cet écran (sinon elle deviendrait une Future non gérée et l'app
  /// resterait silencieusement bloquée sur l'écran de création).
  final Future<void> Function(String path) onVaultReady;

  const OnboardingScreen({
    super.key,
    required this.vaultFolderService,
    required this.onVaultReady,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String? path;
      if (kIsWeb) {
        // Un vrai dossier du disque est la seule option web — la zone
        // privée du navigateur, trop risquée en cas de perte de données,
        // n'est plus jamais proposée pour un nouveau coffre-fort.
        final vault = await widget.vaultFolderService
            .pickAndCreateWebLocalFolderVault();
        path = vault?.vaultPath;
      } else {
        path = await widget.vaultFolderService.pickAndCreateVaultFolder();
      }
      if (path == null) {
        setState(() => _loading = false);
        return;
      }
      await widget.onVaultReady(path);
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        ).onboarding_create_folder_failed(e.toString());
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.folderOpen,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.onboarding_welcome_title,
                  textAlign: TextAlign.center,
                ).large().large().medium(),
                const SizedBox(height: 12),
                Text(
                  l10n.onboarding_description,
                  textAlign: TextAlign.center,
                ).muted(),
                if (kIsWeb) ...[
                  const SizedBox(height: 24),
                  if (widget.vaultFolderService.supportsWebLocalFolder) ...[
                    // Un vrai dossier réel est choisi au clic sur le bouton
                    // ci-dessous (sélecteur natif du navigateur) : pas de
                    // nom à saisir, le nom du dossier choisi sert de nom de
                    // coffre-fort par défaut (voir
                    // `VaultFolderService.pickAndCreateWebLocalFolderVault`).
                    // Seule option web proposée : la zone privée du
                    // navigateur, trop risquée en cas de perte de données,
                    // n'est plus jamais offerte pour un nouveau coffre-fort.
                    Text(
                      l10n.onboarding_web_local_folder_explainer,
                      textAlign: TextAlign.center,
                    ).small().muted(),
                  ] else ...[
                    Text(
                      l10n.core_ui_web_folder_required_title,
                    ).small().medium(),
                    const SizedBox(height: 4),
                    Text(
                      l10n.core_ui_web_folder_required_detail,
                      textAlign: TextAlign.center,
                    ).small().muted(),
                  ],
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed:
                      _loading ||
                          (kIsWeb &&
                              !widget.vaultFolderService.supportsWebLocalFolder)
                      ? null
                      : _pick,
                  leading: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(LucideIcons.folder),
                  child: Text(
                    _loading
                        ? l10n.onboarding_creating
                        : !kIsWeb
                        ? l10n.onboarding_pick_location
                        : l10n.onboarding_web_local_folder_button,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.destructive,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
