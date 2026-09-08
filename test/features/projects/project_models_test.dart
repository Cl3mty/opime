import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/projects/project_models.dart';

void main() {
  group('ProjectAccountLink', () {
    test('aller-retour JSON', () {
      const link = ProjectAccountLink(accountId: 'account_1');
      final decoded = ProjectAccountLink.fromJson(link.toJson());
      expect(decoded.accountId, 'account_1');
    });
  });

  group('ProjectLiabilityLink', () {
    test('aller-retour JSON', () {
      const link = ProjectLiabilityLink(liabilityId: 'liab_1');
      final decoded = ProjectLiabilityLink.fromJson(link.toJson());
      expect(decoded.liabilityId, 'liab_1');
    });
  });

  group('Project', () {
    test(
      'aller-retour JSON avec montantCible, apport mensuel et liens renseignés',
      () {
        final project = Project(
          name: 'Achat résidence principale',
          description: 'Apport pour 2028',
          echeance: DateTime.utc(2028, 6, 1),
          rendementAttendu: 3.5,
          apportMensuel: 200,
          montantCible: 50000,
          accountLinks: const [ProjectAccountLink(accountId: 'account_1')],
          liabilityLinks: const [ProjectLiabilityLink(liabilityId: 'liab_1')],
        );

        final decoded = Project.fromJson(project.toJson());

        expect(decoded.id, project.id);
        expect(decoded.name, 'Achat résidence principale');
        expect(decoded.description, 'Apport pour 2028');
        expect(decoded.echeance, DateTime.utc(2028, 6, 1));
        expect(decoded.rendementAttendu, 3.5);
        expect(decoded.apportMensuel, 200);
        expect(decoded.montantCible, 50000);
        expect(decoded.accountLinks, hasLength(1));
        expect(decoded.accountLinks.first.accountId, 'account_1');
        expect(decoded.liabilityLinks, hasLength(1));
        expect(decoded.liabilityLinks.first.liabilityId, 'liab_1');
      },
    );

    test(
      'montantCible et apport mensuel absents : clés omises du JSON, valeurs par défaut au décodage',
      () {
        final project = Project(
          name: 'Retraite',
          echeance: DateTime.utc(2050, 1, 1),
        );

        final json = project.toJson();
        expect(json.containsKey('montantCible'), isFalse);
        expect(json.containsKey('apportMensuel'), isFalse);

        final decoded = Project.fromJson(json);
        expect(decoded.montantCible, isNull);
        expect(decoded.apportMensuel, 0);
        expect(decoded.accountLinks, isEmpty);
        expect(decoded.liabilityLinks, isEmpty);
      },
    );

    test('copyWith(clearMontantCible: true) efface le montant cible', () {
      final project = Project(
        name: 'Achat',
        echeance: DateTime.utc(2030, 1, 1),
        montantCible: 1000,
      );
      final cleared = project.copyWith(clearMontantCible: true);
      expect(cleared.montantCible, isNull);
    });

    test('décodage tolérant : un ancien lien avec investmentId (position '
        'précise) ne conserve que le compte, dédupliqué s\'il apparaît '
        'plusieurs fois', () {
      final json = {
        'id': 'p1',
        'nom': 'Projet',
        'description': '',
        'echeance': DateTime.utc(2030, 1, 1).toIso8601String(),
        'rendementAttendu': 0,
        'actifs': [
          {'accountId': 'account_1', 'investmentId': 'inv_1'},
          {'accountId': 'account_1', 'investmentId': 'inv_2'},
          {'accountId': 'account_2', 'investmentId': 'inv_3'},
        ],
      };

      final decoded = Project.fromJson(json);

      expect(decoded.accountLinks, hasLength(2));
      expect(decoded.accountLinks.map((l) => l.accountId).toSet(), {
        'account_1',
        'account_2',
      });
    });
  });
}
