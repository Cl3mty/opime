import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../money_format.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Bloc compact pour une cellule de tableau qui affiche un gain/perte
/// (plus-value, évolution de période...) : une flèche colorée (verte vers
/// le haut, rouge vers le bas selon le signe), le montant en euros signé
/// puis, en dessous, le pourcentage — toujours les deux grandeurs
/// affichées ensemble, toujours signées, pour distinguer d'un coup d'œil
/// une valeur actuelle (jamais signée, ex : solde d'un compte, voir
/// [displayEuros]) d'un écart (+/- value, voir [displaySignedEuros]).
/// Factorise ce que plusieurs tableaux de l'app (comptes, catégories,
/// positions) reproduisaient chacun à l'identique.
///
/// [euros] `null` affiche un simple « — » plutôt qu'une flèche/un montant à
/// 0 : distingue un actif dont le cours n'a jamais pu être connu (rien à
/// afficher) d'une plus-value réellement nulle (0,00 € affiché tel quel).
class PerformanceAmount extends StatelessWidget {
  final double? euros;
  final double? percent;
  final bool hidden;

  const PerformanceAmount({
    super.key,
    required this.euros,
    this.percent,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final value = euros;
    if (value == null) {
      // Alignement à droite explicite : contrairement au montant chiffré
      // ci-dessous, un `Text` seul ne remplit pas la largeur d'un parent à
      // largeur fixe (`SizedBox(width: ...)`, l'usage systématique de ce
      // widget dans les tableaux de l'app) — il resterait collé à gauche
      // sans cet `Align`.
      return Align(
        alignment: Alignment.centerRight,
        child: shadcn.Text('—').small(),
      );
    }
    final positive = value >= 0;
    final color = positive ? _green : _red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              positive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 2),
            shadcn.Text(
              displaySignedEuros(value, hidden),
              style: TextStyle(color: color),
            ).xSmall(),
          ],
        ),
        if (percent != null)
          shadcn.Text(
            displayPercent(percent!),
            style: TextStyle(color: color),
          ).muted().xSmall(),
      ],
    );
  }
}
