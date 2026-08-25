/// Évalue une expression arithmétique simple saisie dans une cellule
/// numérique (ex : les cellules Budget/Réalité de Suivi budgétaire,
/// `budget_tracking_screen.dart`) — support des 4 opérations de base
/// (+, -, *, /), des parenthèses, de la priorité multiplication/division
/// sur addition/soustraction, et de la virgule comme séparateur décimal
/// (même convention que [parseDecimal] dans `money_format.dart`). `null`
/// pour une entrée vide, invalide (caractère inattendu, parenthèse non
/// fermée...) ou une division par zéro — jamais d'exception, pour rester
/// utilisable directement dans un `onChanged` de champ de texte pendant la
/// frappe : une expression encore incomplète (ex : "50+") est simplement
/// `null` en attendant la suite, plutôt que de faire planter la saisie.
double? evaluateAmountExpression(String input) {
  final normalized = input.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (normalized.isEmpty) return null;
  final parser = _ExpressionParser(normalized);
  final value = parser.parseExpression();
  if (value == null || !parser.atEnd) return null;
  return value;
}

/// Analyseur récursif descendant sur une [String] déjà normalisée (sans
/// espace, virgule remplacée par un point) : `expression := terme (('+'|'-')
/// terme)*`, `terme := facteur (('*'|'/') facteur)*`, `facteur := '-'
/// facteur | '(' expression ')' | nombre`. Chaque méthode avance [_pos] au
/// fur et à mesure et renvoie `null` dès qu'elle ne reconnaît pas ce
/// qu'elle attend, plutôt que de lever une exception — l'appelant
/// ([evaluateAmountExpression]) vérifie ensuite que tout l'input a bien été
/// consommé ([atEnd]) pour rejeter un reliquat inattendu (ex : "50)").
class _ExpressionParser {
  final String _input;
  int _pos = 0;

  _ExpressionParser(this._input);

  bool get atEnd => _pos >= _input.length;

  double? parseExpression() {
    final first = _parseTerm();
    if (first == null) return null;
    var value = first;
    while (!atEnd && (_input[_pos] == '+' || _input[_pos] == '-')) {
      final op = _input[_pos];
      _pos++;
      final rhs = _parseTerm();
      if (rhs == null) return null;
      value = op == '+' ? value + rhs : value - rhs;
    }
    return value;
  }

  double? _parseTerm() {
    final first = _parseFactor();
    if (first == null) return null;
    var value = first;
    while (!atEnd && (_input[_pos] == '*' || _input[_pos] == '/')) {
      final op = _input[_pos];
      _pos++;
      final rhs = _parseFactor();
      if (rhs == null) return null;
      if (op == '*') {
        value = value * rhs;
      } else {
        if (rhs == 0) return null;
        value = value / rhs;
      }
    }
    return value;
  }

  double? _parseFactor() {
    if (atEnd) return null;
    final ch = _input[_pos];
    if (ch == '-') {
      _pos++;
      final value = _parseFactor();
      return value == null ? null : -value;
    }
    if (ch == '+') {
      _pos++;
      return _parseFactor();
    }
    if (ch == '(') {
      _pos++;
      final value = parseExpression();
      if (value == null || atEnd || _input[_pos] != ')') return null;
      _pos++;
      return value;
    }
    return _parseNumber();
  }

  double? _parseNumber() {
    final start = _pos;
    while (!atEnd && (_isDigit(_input[_pos]) || _input[_pos] == '.')) {
      _pos++;
    }
    if (_pos == start) return null;
    return double.tryParse(_input.substring(start, _pos));
  }

  bool _isDigit(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
