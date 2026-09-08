import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:opime/l10n/app_localizations.dart';
import 'update_checker.dart';

class UpdateBanner extends StatefulWidget {
  final String githubOwner;
  final String githubRepo;
  final Widget child;

  const UpdateBanner({
    super.key,
    required this.githubOwner,
    required this.githubRepo,
    required this.child,
  });

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  static const _dismissedKey = 'dismissed_update_version';

  UpdateInfo? _update;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final checker = UpdateChecker(
      githubOwner: widget.githubOwner,
      githubRepo: widget.githubRepo,
    );
    final info = await checker.checkForUpdate();
    if (!mounted || info == null) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedKey);
    if (dismissedVersion == info.latestVersion) {
      return; // déjà ignorée pour cette version
    }

    if (mounted) setState(() => _update = info);
  }

  Future<void> _dismiss() async {
    if (_update == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, _update!.latestVersion);
    if (mounted) setState(() => _dismissed = true);
  }

  Future<void> _download() async {
    if (_update == null) return;
    final uri = Uri.parse(_update!.downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_update == null || _dismissed) return widget.child;
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: accent.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: shadcn.Text(
                  l10n.updates_banner_new_version(_update!.latestVersion),
                ),
              ),
              PrimaryButton(
                size: ButtonSize.small,
                onPressed: _download,
                leading: const Icon(LucideIcons.download, size: 14),
                child: shadcn.Text(l10n.settings_download_install),
              ),
              const SizedBox(width: 8),
              IconButton.ghost(
                icon: const Icon(LucideIcons.x, size: 14),
                onPressed: _dismiss,
              ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
