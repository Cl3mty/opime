import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;

/// Un identifiant affiché en texte atténué avec un bouton de copie —
/// [ISIN, ticker, référence...] : factorise le pattern texte + icône copie
/// + confirmation par toast, jusqu'ici dupliqué à chaque usage.
class CopyableIdentifier extends StatelessWidget {
  final String value;

  /// Titre du toast de confirmation (ex : "ISIN copié", "Ticker copié").
  final String toastTitle;

  const CopyableIdentifier({
    super.key,
    required this.value,
    required this.toastTitle,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: shadcn.Text(toastTitle),
          subtitle: shadcn.Text(value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        shadcn.Text(value).muted().small(),
        const SizedBox(width: 4),
        IconButton.ghost(
          icon: const Icon(LucideIcons.copy, size: 14),
          onPressed: () => _copy(context),
        ),
      ],
    );
  }
}
