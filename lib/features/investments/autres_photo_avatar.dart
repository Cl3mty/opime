import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
    final imagePath = photoPath;
    final Widget avatar;
    if (imagePath != null && imagePath.isNotEmpty) {
      // Un échec de lecture (fichier supprimé, corrompu...) retombe
      // silencieusement sur les initiales, comme l'avatar des comptes.
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.file(
          File(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initials(),
        ),
      );
    } else {
      avatar = _initials();
    }
    if (onTap == null) return avatar;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }

  Widget _initials() => Avatar(size: size, initials: initialsFor(label));
}
