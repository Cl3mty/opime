import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../storage/vault_fs.dart';

/// Avatar image asynchrone partagé : charge les octets de l'image via
/// l'abstraction du vault ([VaultFile.readAsBytes], identique sur desktop et
/// web OPFS) plutôt que `dart:io Image.file`, non compilable sur web.
///
/// Affiche l'image une fois chargée, [fallback] pendant le chargement ou si
/// le fichier n'existe pas / n'est pas une image lisible. Quand [onTap] est
/// fourni, l'avatar (image ou fallback) est cliquable avec un curseur main.
class VaultImageAvatar extends StatelessWidget {
  final String imagePath;
  final double size;
  final BorderRadius borderRadius;
  final Widget Function() fallback;
  final VoidCallback? onTap;

  const VaultImageAvatar({
    super.key,
    required this.imagePath,
    required this.size,
    required this.borderRadius,
    required this.fallback,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = this.imagePath;
    final fallback = this.fallback;
    final borderRadius = this.borderRadius;
    final size = this.size;
    final onTap = this.onTap;

    Widget avatar() => FutureBuilder<Uint8List>(
      future: VaultFile(imagePath).readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: borderRadius,
            child: Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
          );
        }
        return fallback();
      },
    );

    if (onTap == null) return avatar();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: avatar()),
    );
  }
}