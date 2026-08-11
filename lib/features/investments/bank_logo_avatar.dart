import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../dashboard/dashboard_dummy_data.dart' show initialsFor;

/// Avatar d'une banque : le logo importé par l'utilisateur quand il existe
/// (voir `bank_logo_repository.dart`), sinon les initiales du nom. Quand
/// [onTap] est fourni, l'avatar est cliquable et sert à importer/remplacer
/// le logo — l'utilisateur choisit une image sur son disque au premier
/// affichage de la banque (ou en ajoute une a posteriori).
class BankLogoAvatar extends StatelessWidget {
  final String bankName;
  final String? logoPath;
  final VoidCallback? onTap;
  final double size;

  const BankLogoAvatar({
    super.key,
    required this.bankName,
    this.logoPath,
    this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = logoPath;
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

  Widget _initials() => Avatar(size: size, initials: initialsFor(bankName));
}
