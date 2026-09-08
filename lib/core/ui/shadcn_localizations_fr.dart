import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:shadcn_flutter/shadcn_flutter.dart';
// `ShadcnLocalizationsEn` (le jeu de traductions anglaises par défaut, que
// l'on complète ici plutôt que de repartir de zéro) n'est pas ré-exporté par
// le barrel public `package:shadcn_flutter/shadcn_flutter.dart` — seul ce
// chemin interne y donne accès. API non documentée/non garantie stable :
// une mise à jour de shadcn_flutter pourrait déplacer ce fichier.
// ignore: implementation_imports
import 'package:shadcn_flutter/src/components/locale/shadcn_localizations_en.dart';

/// Traduction française des quelques chaînes internes de shadcn_flutter
/// exposées à l'utilisateur dans les écrans d'Opime (essentiellement les
/// boutons Annuler/Enregistrer de la boîte de dialogue d'[OpimeDatePicker],
/// voir `core/ui/opime_date_picker.dart`) — le paquet ne fournit qu'un jeu
/// de traductions anglaises ([ShadcnLocalizationsEn]) ; toute chaîne non
/// explicitement reprise ici reste héritée de l'anglais plutôt que de rester
/// non traduite.
class ShadcnLocalizationsFr extends ShadcnLocalizationsEn {
  ShadcnLocalizationsFr() : super('fr');

  @override
  String get buttonCancel => 'Annuler';

  @override
  String get buttonSave => 'Enregistrer';

  @override
  String get placeholderDatePicker => 'Choisir une date';
}

class _ShadcnLocalizationsFrDelegate
    extends LocalizationsDelegate<ShadcnLocalizations> {
  const _ShadcnLocalizationsFrDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fr';

  @override
  Future<ShadcnLocalizations> load(Locale locale) =>
      SynchronousFuture<ShadcnLocalizations>(ShadcnLocalizationsFr());

  @override
  bool shouldReload(_ShadcnLocalizationsFrDelegate old) => false;
}

/// Délégué à ajouter à `ShadcnApp.localizationsDelegates` (voir `main.dart`)
/// pour que [ShadcnLocalizationsFr] soit résolu pour la locale française
/// plutôt que l'anglais par défaut de shadcn_flutter (`ShadcnLocalizations.delegate`,
/// qui ne prend en charge que `en` et resterait donc sans effet une fois la
/// locale de l'app forcée en français).
const shadcnLocalizationsFrDelegate = _ShadcnLocalizationsFrDelegate();
