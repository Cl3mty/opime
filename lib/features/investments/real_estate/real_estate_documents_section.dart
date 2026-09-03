import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/frosted_card.dart';
import '../confirm_delete_dialog.dart';
import '../document_storage.dart';
import '../investments_models.dart';

/// Catégories proposées pour un document de bien immobilier — texte libre
/// côté modèle (voir [VaultDocument.category]), fermé côté UI pour garder
/// le classement cohérent d'un bien à l'autre.
const kRealEstateDocumentCategories = [
  'Facture',
  'Plan',
  'Photo',
  'Quittance',
  'Autre',
];

/// Section "Documents" d'un bien immobilier — variante catégorisée de
/// `DocumentsSection` (Facture/Plan/Photo/Quittance/Autre) avec une grille
/// de vignettes pour la catégorie "Photo" plutôt qu'une liste de fichiers,
/// et des filtres par catégorie. Volontairement un widget séparé plutôt
/// qu'une extension de `DocumentsSection` : celle-ci est réutilisée telle
/// quelle par une dizaine d'appelants qui n'ont aucun besoin de catégorie,
/// changer sa signature partagée (`onAdd`) pour ce seul usage aurait
/// propagé un paramètre inutile partout ailleurs.
class RealEstateDocumentsSection extends StatefulWidget {
  final String vaultPath;
  final List<VaultDocument> documents;
  final Future<void> Function(
    String fileName,
    Uint8List bytes,
    String category,
    String? name,
  )
  onAdd;
  final ValueChanged<VaultDocument> onDelete;

  const RealEstateDocumentsSection({
    super.key,
    required this.vaultPath,
    required this.documents,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<RealEstateDocumentsSection> createState() =>
      _RealEstateDocumentsSectionState();
}

class _RealEstateDocumentsSectionState
    extends State<RealEstateDocumentsSection> {
  String? _filter; // null = "Tous"

  List<VaultDocument> get _filtered {
    final filter = _filter;
    if (filter == null) return widget.documents;
    return [
      for (final d in widget.documents)
        if ((d.category ?? 'Autre') == filter) d,
    ];
  }

  Future<void> _pickAndAdd() async {
    final details = await _promptDocumentDetails(context);
    if (details == null) return;
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await widget.onAdd(file.name, bytes, details.category, details.name);
  }

  Future<({String category, String? name})?> _promptDocumentDetails(
    BuildContext context,
  ) {
    final nameController = TextEditingController();
    var category = kRealEstateDocumentCategories.first;
    return showDialog<({String category, String? name})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: FrostedCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const shadcn.Text(
                      'Ajouter un document',
                    ).large().semiBold(),
                    const SizedBox(height: 12),
                    shadcn.Text('Catégorie').muted().xSmall(),
                    const SizedBox(height: 4),
                    Select<String>(
                      value: category,
                      itemBuilder: (context, value) => shadcn.Text(value),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => category = v);
                      },
                      popup: (context) => SelectPopup(
                        items: SelectItemList(
                          children: [
                            for (final c in kRealEstateDocumentCategories)
                              SelectItemButton(
                                value: c,
                                child: shadcn.Text(c),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      placeholder: const shadcn.Text(
                        'Nom du document (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        PrimaryButton(
                          onPressed: () => Navigator.of(context).pop((
                            category: category,
                            name: nameController.text.trim().isEmpty
                                ? null
                                : nameController.text.trim(),
                          )),
                          child: const shadcn.Text('Continuer'),
                        ),
                        const SizedBox(width: 8),
                        OutlineButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const shadcn.Text('Annuler'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(VaultDocument document) async {
    final storage = DocumentStorage(widget.vaultPath);
    if (!await storage.fileFor(document).exists()) return;
    final file = await storage.materializeForExternalOpen(document);
    await launchUrl(Uri.file(file.path));
  }

  Future<void> _confirmAndDelete(VaultDocument document) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Supprimer "${document.fileName}" ?',
      message: 'Le fichier sera définitivement supprimé du coffre-fort.',
    );
    if (!confirmed) return;
    widget.onDelete(document);
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      for (final c in kRealEstateDocumentCategories) c: 0,
    };
    for (final d in widget.documents) {
      final category = d.category ?? 'Autre';
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final filtered = _filtered;
    final isPhotoFilter = _filter == 'Photo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const shadcn.Text('Documents').large().medium(),
            const Spacer(),
            GestureDetector(
              onTap: _pickAndAdd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.plus,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  shadcn.Text(
                    'Ajouter',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CategoryChip(
              label: 'Tous (${widget.documents.length})',
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            for (final category in kRealEstateDocumentCategories)
              _CategoryChip(
                label: '$category (${counts[category]})',
                selected: _filter == category,
                onTap: () => setState(() => _filter = category),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          shadcn.Text('Aucun document pour l\'instant.').muted().small()
        else if (isPhotoFilter)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final document in filtered)
                _PhotoThumbnail(
                  vaultPath: widget.vaultPath,
                  document: document,
                  onOpen: () => _open(document),
                  onDelete: () => _confirmAndDelete(document),
                ),
            ],
          )
        else
          for (final document in filtered) ...[
            _RealEstateDocumentRow(
              document: document,
              onOpen: () => _open(document),
              onDelete: () => _confirmAndDelete(document),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : null,
            border: Border.all(color: theme.colorScheme.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: shadcn.Text(
            label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.primaryForeground
                  : theme.colorScheme.mutedForeground,
            ),
          ).xSmall(),
        ),
      ),
    );
  }
}

class _RealEstateDocumentRow extends StatelessWidget {
  final VaultDocument document;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _RealEstateDocumentRow({
    required this.document,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onOpen,
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText,
                  size: 18,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      shadcn.Text(document.fileName).small(),
                      if (document.note != null)
                        shadcn.Text(document.note!).muted().xSmall(),
                    ],
                  ),
                ),
                OutlineBadge(
                  child: shadcn.Text(
                    document.category ?? 'Autre',
                  ).xSmall(),
                ),
                const SizedBox(width: 8),
                shadcn.Text(_formatDate(document.uploadedAt)).muted().xSmall(),
                IconButton.ghost(
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Vignette carrée d'une photo — lit les octets déchiffrés à la demande
/// (voir [DocumentStorage.readBytes]) plutôt qu'un chemin de fichier direct,
/// pour rester valide même sur un vault chiffré (même raison que
/// `materializeForExternalOpen`, réutilisé ici pour l'ouverture externe au
/// clic).
class _PhotoThumbnail extends StatelessWidget {
  final String vaultPath;
  final VaultDocument document;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _PhotoThumbnail({
    required this.vaultPath,
    required this.document,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onOpen,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 96,
                child: FutureBuilder<Uint8List>(
                  future: DocumentStorage(vaultPath).readBytes(document),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return ColoredBox(
                        color: theme.colorScheme.muted,
                        child: Icon(
                          LucideIcons.image,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => ColoredBox(
                        color: theme.colorScheme.muted,
                        child: Icon(
                          LucideIcons.image,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.background.withValues(
                        alpha: 0.85,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.x, size: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
