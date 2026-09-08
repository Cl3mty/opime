/// Formatte un montant en euros avec séparateur de milliers (espace) :
/// `1234567.8` -> `"1 234 568 €"`.
String formatEuros(double value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final s = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(s[i]);
  }
  return '${negative ? '-' : ''}${buffer.toString()} €';
}

/// Version compacte pour les axes/légendes de graphiques :
/// `1500` -> `"2 k €"`, `2500000` -> `"3 M€"`.
String formatEurosCompact(double value) {
  final abs = value.abs();
  if (abs >= 1000000) return '${(value / 1000000).round()} M€';
  if (abs >= 1000) return '${(value / 1000).round()} k €';
  return '${value.round()} €';
}

/// Remplace chaque chiffre d'un montant déjà formaté par un astérisque, en
/// conservant la ponctuation (espaces, virgule, suffixe monétaire) pour que
/// le masquage garde la forme visuelle du montant d'origine.
String maskAmount(String formatted) => formatted.replaceAll(RegExp(r'\d'), '*');

/// Point d'entrée principal utilisé par les écrans : bascule automatiquement
/// entre le montant réel et sa version masquée selon [hidden] (piloté par le
/// toggle de la top bar).
String displayEuros(double value, bool hidden) {
  final formatted = formatEuros(value);
  return hidden ? maskAmount(formatted) : formatted;
}

String displayEurosCompact(double value, bool hidden) {
  final formatted = formatEurosCompact(value);
  return hidden ? maskAmount(formatted) : formatted;
}

/// Comme [formatEuros], mais avec un signe explicite (`+`/`-`) même pour une
/// valeur positive — [formatEuros] n'ajoute jamais de `+`, ce qui convient à
/// une valeur absolue (solde d'un compte, cours...) mais rend un écart
/// (plus-value, évolution de période) ambigu : sans signe visible, rien ne
/// distingue à l'œil une valeur actuelle d'un gain. Réservé aux montants qui
/// représentent un +/- (jamais à [formatEuros]/[displayEuros], toujours
/// utilisés pour une valeur actuelle).
String formatSignedEuros(double value) {
  final formatted = formatEuros(value.abs());
  return value >= 0 ? '+$formatted' : '-$formatted';
}

String displaySignedEuros(double value, bool hidden) {
  final formatted = formatSignedEuros(value);
  return hidden ? maskAmount(formatted) : formatted;
}

/// Formatte une variation en pourcentage avec signe explicite :
/// `1.5` -> `"+1.50 %"`, `-3` -> `"-3.00 %"`.
String displayPercent(double value) {
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)} %';
}

/// Arrondit à 2 décimales une valeur avant persistance sur disque (montants,
/// quantités, cours...) : une précision au centime est amplement suffisante
/// pour ces usages, et évite de stocker le bruit en fin de flottant que
/// laissent les calculs en cascade (tableau d'amortissement, cours
/// convertis...). Volontairement pas utilisé pour les cryptomonnaies, dont
/// la quantité/le cours ont un sens en dessous du centime — voir les
/// appelants (`investments_models.dart`, `liabilities_models.dart`).
double round2(double value) => (value * 100).round() / 100;

/// Parse un nombre saisi par l'utilisateur en acceptant le point comme la
/// virgule comme séparateur décimal (« 1,5 » == « 1.5 »), après
/// suppression des espaces de tête/de fin. `null` si [text] est `null` ou
/// n'est pas un nombre valide. Point d'entrée unique de toutes les saisies
/// numériques de l'app (montants, quantités, taux...).
double? parseDecimal(String? text) {
  if (text == null) return null;
  return double.tryParse(text.trim().replaceAll(',', '.'));
}
