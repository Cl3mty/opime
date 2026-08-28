import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/ui/shadcn_localizations_fr.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('traduit les boutons Annuler/Enregistrer et le texte de repli du '
      'sélecteur de date, plutôt que l\'anglais par défaut de '
      'shadcn_flutter', () {
    final localizations = ShadcnLocalizationsFr();
    expect(localizations.buttonCancel, 'Annuler');
    expect(localizations.buttonSave, 'Enregistrer');
    expect(localizations.placeholderDatePicker, 'Choisir une date');
  });

  test('le délégué ne prend en charge que la locale française', () async {
    expect(
      shadcnLocalizationsFrDelegate.isSupported(const Locale('fr')),
      isTrue,
    );
    expect(
      shadcnLocalizationsFrDelegate.isSupported(const Locale('en')),
      isFalse,
    );
    final resolved = await shadcnLocalizationsFrDelegate.load(
      const Locale('fr'),
    );
    expect(resolved.buttonSave, 'Enregistrer');
  });
}
