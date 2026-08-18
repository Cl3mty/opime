import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:opime/core/storage/vault_crypto.dart';
import 'package:opime/core/storage/vault_session.dart';
import 'package:opime/features/investments/document_storage.dart';
import 'package:opime/features/investments/investments_models.dart';
import 'package:opime/features/investments/metal_mirror_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('opime_mirror_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> readTransactionJson(File file) async {
    final content = await file.readAsString();
    final list = jsonDecode(content) as List;
    return (list.single as Map<String, dynamic>);
  }

  test('projette les transactions métaux avec leurs documents par métal et date', () async {
    final vault = tempDir.path;
    final repo = MetalMirrorRepository(vault);
    final docStorage = DocumentStorage(vault);

    final date = DateTime(2026, 8, 11, 14, 30);
    final facture = VaultDocument(
      fileName: 'facture.png',
      note: 'Facture',
      transactionId: 'txn_1',
    );
    await docStorage.save(facture, Uint8List.fromList([1, 2, 3]));
    final scelle = VaultDocument(
      fileName: 'scellé.pdf',
      note: 'Scellé',
      transactionId: 'txn_1',
    );
    await docStorage.save(scelle, Uint8List.fromList([4, 5, 6]));

    final account = InvestmentAccount(
      assetClass: AssetClass.metauxPrecieux,
      envelope: AccountEnvelope.coffrePersonnel,
      name: 'Coffre maison',
      investments: [
        Investment(
          id: 'inv_1',
          isin: '20 Francs Napoléon',
          label: '20 Francs Napoléon',
          transactions: [
            Transaction(
              id: 'txn_1',
              date: date,
              isBuy: true,
              quantity: 2,
              unitPrice: 650.0,
            ),
          ],
          documents: [facture, scelle],
        ),
      ],
    );

    await repo.sync([account]);

    final dayDir = Directory(
      p.join(
        vault,
        'investissements',
        'metaux_precieux',
        'or',
        dayKey(date),
      ),
    );
    expect(dayDir.existsSync(), isTrue);

    final txnJson = await readTransactionJson(
      File(p.join(dayDir.path, 'transaction.json')),
    );
    expect(txnJson['id'], 'txn_1');
    expect(txnJson['type'], 'achat');
    expect(txnJson['quantite'], 2.0);
    expect(txnJson['investissement'], '20 Francs Napoléon');
    expect(txnJson['compte'], 'Coffre maison');
    expect(txnJson['documents'], containsAll(['facture.png', 'scellé.pdf']));

    // Les fichiers sont copiés sous leur nom d'origine dans le dossier daté.
    expect(File(p.join(dayDir.path, 'facture.png')).existsSync(), isTrue);
    expect(File(p.join(dayDir.path, 'scellé.pdf')).existsSync(), isTrue);
  });

  test('une transaction saisie en devise étrangère projette devise et taux',
      () async {
    final vault = tempDir.path;
    final repo = MetalMirrorRepository(vault);

    final account = InvestmentAccount(
      assetClass: AssetClass.metauxPrecieux,
      envelope: AccountEnvelope.coffrePersonnel,
      name: 'Coffre maison',
      investments: [
        Investment(
          id: 'inv_5',
          isin: 'Pièce US',
          label: 'Pièce US',
          transactions: [
            Transaction(
              id: 'txn_5',
              date: DateTime(2026, 8, 11),
              isBuy: true,
              quantity: 1,
              unitPrice: 250,
              currency: 'USD',
              fxRateToEur: 0.92,
            ),
          ],
        ),
      ],
    );

    await repo.sync([account]);

    final txnJson = await readTransactionJson(
      File(
        p.join(
          vault,
          'investissements',
          'metaux_precieux',
          'or',
          '2026-08-11',
          'transaction.json',
        ),
      ),
    );
    expect(txnJson['devise'], 'USD');
    expect(txnJson['tauxEur'], 0.92);
    // Montant toujours en euros : 1 × 250 $ × 0,92 = 230 €.
    expect(txnJson['montant'], 230.0);
  });

  test('range une pièce d\'argent sous le dossier argent', () async {
    final vault = tempDir.path;
    final repo = MetalMirrorRepository(vault);

    final account = InvestmentAccount(
      assetClass: AssetClass.metauxPrecieux,
      envelope: AccountEnvelope.coffreBancaire,
      name: 'Coffre banque',
      investments: [
        Investment(
          id: 'inv_2',
          isin: '5 Francs Semeuse 1959-1969',
          label: '5 Francs Semeuse 1959-1969',
          transactions: [
            Transaction(
              id: 'txn_2',
              date: DateTime(2026, 7, 3),
              isBuy: true,
              quantity: 10,
              unitPrice: 15.4,
            ),
          ],
        ),
      ],
    );

    await repo.sync([account]);

    final dayDir = Directory(
      p.join(vault, 'investissements', 'metaux_precieux', 'argent', '2026-07-03'),
    );
    expect(dayDir.existsSync(), isTrue);
    expect(
      Directory(p.join(vault, 'investissements', 'metaux_precieux', 'or'))
          .existsSync(),
      isFalse,
    );
  });

  test('retire un dossier daté devenu sans objet et nettoie les fichiers orphelins', () async {
    final vault = tempDir.path;
    final repo = MetalMirrorRepository(vault);

    final account = InvestmentAccount(
      assetClass: AssetClass.metauxPrecieux,
      envelope: AccountEnvelope.coffrePersonnel,
      name: 'Coffre maison',
      investments: [
        Investment(
          id: 'inv_3',
          isin: 'Lingot 100g Or',
          label: 'Lingot 100g Or',
          transactions: [
            Transaction(
              id: 'txn_3',
              date: DateTime(2026, 8, 11),
              isBuy: true,
              quantity: 1,
              unitPrice: 11870.0,
            ),
          ],
        ),
      ],
    );
    await repo.sync([account]);

    final dayDir = Directory(
      p.join(vault, 'investissements', 'metaux_precieux', 'or', '2026-08-11'),
    );
    // Un fichier parasite posé à la main dans le dossier daté.
    final orphan = File(p.join(dayDir.path, 'ancien.pdf'));
    await orphan.writeAsString('x');

    // La transaction est supprimée : le miroir ne doit plus rien contenir.
    final emptyAccount = account.copyWith(
      investments: [
        account.investments.single.copyWith(transactions: const []),
      ],
    );
    await repo.sync([emptyAccount]);

    expect(dayDir.existsSync(), isFalse);
    expect(
      Directory(p.join(vault, 'investissements', 'metaux_precieux', 'or'))
          .existsSync(),
      isFalse,
    );
    expect(
      Directory(p.join(vault, 'investissements', 'metaux_precieux'))
          .existsSync(),
      isFalse,
    );
  });

  test(
    'un document source chiffré est copié en clair dans le miroir '
    '(pas un copy() brut des octets chiffrés)',
    () async {
      final vault = tempDir.path;
      final cipher = VaultCipher(generateDek());
      final repo = MetalMirrorRepository(vault);
      final docStorage = DocumentStorage(vault, cipher: cipher);

      final originalBytes = Uint8List.fromList([9, 8, 7, 6, 5]);
      final facture = VaultDocument(
        fileName: 'facture.png',
        note: 'Facture',
        transactionId: 'txn_6',
      );
      await docStorage.save(facture, originalBytes);

      // Le fichier source, lui, est bien chiffré sur disque (sinon ce test
      // ne prouverait rien).
      final sourceBytes = await docStorage.fileFor(facture).readAsBytes();
      expect(sourceBytes, isNot(originalBytes));

      final account = InvestmentAccount(
        assetClass: AssetClass.metauxPrecieux,
        envelope: AccountEnvelope.coffrePersonnel,
        name: 'Coffre maison',
        investments: [
          Investment(
            id: 'inv_6',
            isin: '20 Francs Napoléon',
            label: '20 Francs Napoléon',
            transactions: [
              Transaction(
                id: 'txn_6',
                date: DateTime(2026, 8, 11),
                isBuy: true,
                quantity: 1,
                unitPrice: 650.0,
              ),
            ],
            documents: [facture],
          ),
        ],
      );

      // sync() lit lui-même via VaultSession.current, jamais un cipher
      // explicite passé en paramètre — même mécanisme que les repositories
      // en session réelle (voir `vault_session.dart`).
      VaultSession.current = cipher;
      try {
        await repo.sync([account]);
      } finally {
        VaultSession.current = null;
      }

      final mirrored = File(
        p.join(
          vault,
          'investissements',
          'metaux_precieux',
          'or',
          '2026-08-11',
          'facture.png',
        ),
      );
      expect(await mirrored.readAsBytes(), originalBytes);
    },
  );

  test('ne crée rien sans investissement métal détenu', () async {
    final vault = tempDir.path;
    final repo = MetalMirrorRepository(vault);

    final account = InvestmentAccount(
      assetClass: AssetClass.actionsEtFonds,
      envelope: AccountEnvelope.cto,
      name: 'CTO',
      investments: [
        Investment(
          id: 'inv_4',
          isin: 'FR0000120271',
          label: 'TotalEnergies',
          transactions: [
            Transaction(
              id: 'txn_4',
              date: DateTime(2026, 8, 11),
              isBuy: true,
              quantity: 10,
              unitPrice: 60.0,
            ),
          ],
        ),
      ],
    );

    await repo.sync([account]);

    expect(
      Directory(p.join(vault, 'investissements', 'metaux_precieux')).existsSync(),
      isFalse,
    );
  });
}
