String formatDateDdMmYyyy(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

/// Mois en français, `frenchMonths[date.month - 1]`.
const frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// "24 avril 2026" — jour sans zéro, mois en toutes lettres, comme une date
/// s'écrit en prose française (à l'inverse du "April 24, 2026" anglo-saxon
/// que rend shadcn_flutter par défaut — voir `OpimeDatePicker`).
String formatDateFrLong(DateTime date) =>
    '${date.day} ${frenchMonths[date.month - 1]} ${date.year}';
