import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import 'package:url_launcher/url_launcher.dart';
import '../../core/money_format.dart';
import '../../core/ui/frosted_card.dart';
import '../../l10n/app_localizations.dart';
import 'confirm_delete_dialog.dart';
import 'currency_format.dart';
import 'document_storage.dart';
import 'investments_models.dart';

/// Libellé compact d'une transaction pour le choix "rattacher à quelle
/// transaction ?" et pour le tag affiché sur un document déjà rattaché.
/// [quantityAssetClass] sert à formater la quantité (entière pour les
/// pièces/lingots de métaux précieux).
String _transactionLabel(
  Transaction transaction,
  AssetClass? quantityAssetClass,
) {
  final date = transaction.date;
  final formattedDate =
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
  final kind = transaction.displayLabel;
  // Prix unitaire dans sa devise de cotation (USD pour une action US...)
  // plutôt qu'en euros quand la transaction a été saisie hors euros.
  final price = transaction.currency == 'EUR'
      ? displayEuros(transaction.unitPrice, false)
      : formatPriceInCurrency(transaction.unitPrice, transaction.currency);
  return '$kind du $formattedDate • '
      '${quantityAssetClass != null ? formatQuantity(transaction.quantity, quantityAssetClass) : transaction.quantity.toStringAsFixed(2)} × '
      '$price';
}

/// Section "Documents" réutilisée à l'identique sur la page d'un compte,
/// d'un passif et d'un investissement : upload (sélecteur de fichier
/// natif, avec un nom optionnel donné à l'ajout), liste avec ouverture à
/// la demande (via l'application par défaut du système — pas de
/// visualiseur PDF/image embarqué) et suppression. Le contenu réel des
/// fichiers est stocké à part par [DocumentStorage] ; [documents] ne porte
/// que les métadonnées, déjà persistées par l'appelant via
/// [onAdd]/[onDelete].
///
/// Quand [fixedTransactionId] est fourni, chaque nouveau document est
/// automatiquement rattaché à cette transaction (utilisé depuis son propre
/// formulaire d'édition — voir `InvestmentDetailView`). Sinon, quand
/// [transactions] est fourni (non `null`), chaque nouveau document doit
/// être rattaché à l'une des transactions listées (facture, photo à
/// l'appui d'un achat physique — typiquement les métaux précieux) : l'ajout
/// ouvre d'abord un choix de transaction avant le sélecteur de fichier, et
/// la liste affiche à quelle transaction chaque document est rattaché.
class DocumentsSection extends StatelessWidget {
  final String vaultPath;

  /// Sous-dossier où sont stockés les octets des documents — voir
  /// [DocumentStorage.dirRelativePath]. `null` garde le dossier historique
  /// (comptes/investissements) ; un autre appelant (ex : les notes de
  /// `strategy/`) passe son propre sous-dossier.
  final String? documentsFolder;

  final List<VaultDocument> documents;
  final List<Transaction>? transactions;
  final String? fixedTransactionId;
  final Future<void> Function(
    String fileName,
    Uint8List bytes,
    String? transactionId,
    String? name,
  )
  onAdd;
  final ValueChanged<VaultDocument> onDelete;

  /// Classe d'actif de l'élément auquel on rattache des documents : sert à
  /// formater la quantité des transactions listées (entière pour les métaux
  /// précieux). `null` (passif) : formatage par défaut.
  final AssetClass? quantityAssetClass;

  const DocumentsSection({
    super.key,
    required this.vaultPath,
    this.documentsFolder,
    required this.documents,
    this.transactions,
    this.fixedTransactionId,
    this.quantityAssetClass,
    required this.onAdd,
    required this.onDelete,
  });

  Future<void> _pickAndAdd(BuildContext context) async {
    final fixedTransactionId = this.fixedTransactionId;
    final linkedTransactions = transactions;
    String? transactionId = fixedTransactionId;
    String? name;

    if (fixedTransactionId == null && linkedTransactions != null) {
      if (linkedTransactions.isEmpty) {
        final l10n = AppLocalizations.of(context);
        showToast(
          context: context,
          location: ToastLocation.bottomRight,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              title: shadcn.Text(l10n.investments_documents_no_transaction_title),
              subtitle: shadcn.Text(
                l10n.investments_documents_no_transaction_message,
              ),
            ),
          ),
        );
        return;
      }
      final details = await _promptDocumentDetails(
        context,
        transactionOptions: linkedTransactions,
      );
      if (details == null) return;
      name = details.name;
      transactionId = details.transactionId;
    } else {
      final details = await _promptDocumentDetails(context);
      if (details == null) return;
      name = details.name;
    }

    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await onAdd(file.name, bytes, transactionId, name);
  }

  /// Un seul dialogue combine le nom (toujours) et, si [transactionOptions]
  /// est fourni, le choix de la transaction — sélectionner une transaction
  /// referme directement le dialogue (pas de bouton "Continuer" séparé),
  /// le champ nom devant alors déjà être rempli.
  Future<({String? name, String? transactionId})?> _promptDocumentDetails(
    BuildContext context, {
    List<Transaction>? transactionOptions,
  }) {
    final nameController = TextEditingController();
    return showDialog<({String? name, String? transactionId})>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shadcn.Text(l10n.real_estate_add_document_title).large().semiBold(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    placeholder: shadcn.Text(
                      l10n.real_estate_document_name_hint,
                    ),
                    autofocus: true,
                  ),
                  if (transactionOptions != null) ...[
                    const SizedBox(height: 16),
                    shadcn.Text(
                      l10n.investments_documents_link_transaction_label,
                    ).small().semiBold(),
                    const SizedBox(height: 8),
                    for (final transaction in transactionOptions.reversed) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop((
                          name: nameController.text.trim().isEmpty
                              ? null
                              : nameController.text.trim(),
                          transactionId: transaction.id,
                        )),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: FrostedCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: shadcn.Text(
                                _transactionLabel(
                                  transaction,
                                  quantityAssetClass,
                                ),
                              ).small(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ] else
                    const SizedBox(height: 16),
                  Row(
                    children: [
                      if (transactionOptions == null)
                        PrimaryButton(
                          onPressed: () => Navigator.of(context).pop((
                            name: nameController.text.trim().isEmpty
                                ? null
                                : nameController.text.trim(),
                            transactionId: null,
                          )),
                          child: shadcn.Text(l10n.common_continue),
                        ),
                      if (transactionOptions == null) const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: shadcn.Text(l10n.common_cancel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  String? _labelFor(String? transactionId) {
    if (transactionId == null) return null;
    for (final transaction in transactions ?? const []) {
      if (transaction.id == transactionId) {
        return _transactionLabel(transaction, quantityAssetClass);
      }
    }
    return null;
  }

  Future<void> _open(VaultDocument document) async {
    final folder = documentsFolder;
    final storage = folder == null
        ? DocumentStorage(vaultPath)
        : DocumentStorage(vaultPath, dirRelativePath: folder);
    if (!await storage.fileFor(document).exists()) return;
    final file = await storage.materializeForExternalOpen(document);
    await launchUrl(Uri.file(file.path));
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    VaultDocument document,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDelete(
      context,
      title: l10n.real_estate_delete_document_title(document.fileName),
      message: l10n.real_estate_delete_document_message,
    );
    if (!confirmed) return;
    onDelete(document);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            shadcn.Text(l10n.real_estate_documents_title).large().medium(),
            const Spacer(),
            GestureDetector(
              onTap: () => _pickAndAdd(context),
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
                    l10n.common_add,
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
        if (documents.isEmpty)
          shadcn.Text(l10n.investments_documents_empty).muted().small()
        else
          for (final document in documents) ...[
            _DocumentRow(
              document: document,
              transactionLabel: _labelFor(document.transactionId),
              onOpen: () => _open(document),
              onDelete: () => _confirmAndDelete(context, document),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

/// Dialogue de consultation (lecture seule) des documents d'une transaction
/// — liste cliquable, chaque ligne ouvre le fichier via l'application par
/// défaut du système (même mécanisme que [DocumentsSection]). Utilisé depuis
/// la rangée d'une transaction (métaux précieux et "autres", voir
/// `InvestmentDetailView`'s `_usesTransactionScopedDocuments`) pour
/// visualiser les pièces justificatives sans passer par l'édition de la
/// transaction. L'ajout/la suppression reste sur la section d'édition.
Future<void> showDocumentViewDialog(
  BuildContext context, {
  required String vaultPath,
  required List<VaultDocument> documents,
  String? documentsFolder,
}) async {
  Future<void> open(VaultDocument document) async {
    final storage = documentsFolder == null
        ? DocumentStorage(vaultPath)
        : DocumentStorage(vaultPath, dirRelativePath: documentsFolder);
    if (!await storage.fileFor(document).exists()) return;
    final file = await storage.materializeForExternalOpen(document);
    await launchUrl(Uri.file(file.path));
  }

  return showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: FrostedCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shadcn.Text(
                  l10n.investments_documents_view_dialog_title,
                ).large().semiBold(),
                const SizedBox(height: 4),
                shadcn.Text(
                  l10n.investments_documents_view_dialog_subtitle(
                    documents.length,
                  ),
                ).muted().small(),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final document in documents) ...[
                          _DocumentRow(
                            document: document,
                            onOpen: () => open(document),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlineButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: shadcn.Text(l10n.common_close),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
    },
  );
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}

class _DocumentRow extends StatelessWidget {
  final VaultDocument document;
  final String? transactionLabel;
  final VoidCallback onOpen;

  /// `null` en mode consultation seule (dialogue de visualisation) : le
  /// bouton de suppression est alors masqué.
  final VoidCallback? onDelete;

  const _DocumentRow({
    required this.document,
    this.transactionLabel,
    required this.onOpen,
    this.onDelete,
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
                      if (transactionLabel != null)
                        shadcn.Text(transactionLabel!).muted().xSmall(),
                    ],
                  ),
                ),
                shadcn.Text(_formatDate(document.uploadedAt)).muted().xSmall(),
                if (onDelete != null)
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
