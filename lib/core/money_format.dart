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
