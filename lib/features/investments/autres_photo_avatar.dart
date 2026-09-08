import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../core/ui/vault_image_avatar.dart';
import '../dashboard/patrimoine_models.dart' show initialsFor;

/// Avatar d'un objet "Autres" (montre, voiture de collection, art...) : la
/// photo importée par l'utilisateur quand elle existe (voir
/// `autres_photo_repository.dart`), sinon les initiales de son libellé —
/// même principe que `BankLogoAvatar` pour le logo d'une banque. Quand
/// [onTap] est fourni, l'avatar est cliquable et sert à importer/remplacer
/// la photo.
class AutresPhotoAvatar extends StatelessWidget {
  final String label;
  final String? photoPath;
  final VoidCallback? onTap;
  final double size;

  const AutresPhotoAvatar({
    super.key,
    required this.label,
    this.photoPath,
    this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return VaultImageAvatar(
      imagePath: photoPath ?? '',
      size: size,
      borderRadius: BorderRadius.circular(size / 2),
      fallback: () => Avatar(size: size, initials: initialsFor(label)),
      onTap: onTap,
    );
  }
}