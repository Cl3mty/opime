import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../core/ui/vault_image_avatar.dart';
import '../dashboard/patrimoine_models.dart' show initialsFor;

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
    return VaultImageAvatar(
      imagePath: logoPath ?? '',
      size: size,
      borderRadius: BorderRadius.circular(size / 2),
      fallback: () => Avatar(size: size, initials: initialsFor(bankName)),
      onTap: onTap,
    );
  }
}