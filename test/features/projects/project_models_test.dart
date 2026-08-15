import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/projects/project_models.dart';

void main() {
  group('ProjectAssetLink', () {
    test('aller-retour JSON', () {
      const link = ProjectAssetLink(accountId: 'account_1', investmentId: 'inv_1');
      final decoded = ProjectAssetLink.fromJson(link.toJson());
      expect(decoded.accountId, 'account_1');
      expect(decoded.investmentId, 'inv_1');
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
    test('aller-retour JSON avec montantCible et liens renseignés', () {
      final project = Project(
        name: 'Achat résidence principale',
        description: 'Apport pour 2028',
        echeance: DateTime.utc(2028, 6, 1),
        rendementAttendu: 3.5,
        montantCible: 50000,
        assetLinks: const [
          ProjectAssetLink(accountId: 'account_1', investmentId: 'inv_1'),
        ],
        liabilityLinks: const [ProjectLiabilityLink(liabilityId: 'liab_1')],
      );

      final decoded = Project.fromJson(project.toJson());

      expect(decoded.id, project.id);
      expect(decoded.name, 'Achat résidence principale');
      expect(decoded.description, 'Apport pour 2028');
      expect(decoded.echeance, DateTime.utc(2028, 6, 1));
      expect(decoded.rendementAttendu, 3.5);
      expect(decoded.montantCible, 50000);
      expect(decoded.assetLinks, hasLength(1));
      expect(decoded.assetLinks.first.accountId, 'account_1');
      expect(decoded.liabilityLinks, hasLength(1));
      expect(decoded.liabilityLinks.first.liabilityId, 'liab_1');
    });

    test('montantCible absent : clé omise du JSON, null au décodage', () {
      final project = Project(
        name: 'Retraite',
        echeance: DateTime.utc(2050, 1, 1),
      );

      final json = project.toJson();
      expect(json.containsKey('montantCible'), isFalse);

      final decoded = Project.fromJson(json);
      expect(decoded.montantCible, isNull);
      expect(decoded.assetLinks, isEmpty);
      expect(decoded.liabilityLinks, isEmpty);
    });

    test('copyWith(clearMontantCible: true) efface le montant cible', () {
      final project = Project(
        name: 'Achat',
        echeance: DateTime.utc(2030, 1, 1),
        montantCible: 1000,
      );
      final cleared = project.copyWith(clearMontantCible: true);
      expect(cleared.montantCible, isNull);
    });
  });
}
