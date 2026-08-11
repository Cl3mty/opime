import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart';

void main() {
  InvestmentAccount account({String? description}) => InvestmentAccount(
    assetClass: AssetClass.epargne,
    envelope: AccountEnvelope.livretA,
    name: 'Boursorama',
    bankName: 'Boursorama',
    description: description,
    investments: const [],
  );

  test('description round-trip JSON', () {
    final a = account(description: 'Épargne vacances');
    final b = InvestmentAccount.fromJson(a.toJson());
    expect(b.description, 'Épargne vacances');
  });

  test('description absente (ou vide) round-trip vers null', () {
    final a = account();
    final b = InvestmentAccount.fromJson(a.toJson());
    expect(b.description, isNull);
  });

  test('copyWith efface la description avec null explicite', () {
    final a = account(description: 'Épargne vacances');
    expect(a.copyWith(description: null).description, isNull);
    // Paramètre non fourni : la description est conservée.
    expect(a.copyWith(name: 'Renommé').description, 'Épargne vacances');
  });

  test('requiresLabelFieldFor : pas de libellé séparé pour l\'épargne', () {
    expect(requiresLabelFieldFor(AssetClass.epargne), isFalse);
    expect(
      requiresLabelFieldFor(
        AssetClass.metauxPrecieux,
        accountEnvelope: AccountEnvelope.coffrePersonnel,
      ),
      isFalse,
    );
    // Un ETC métaux dans un CTO est un titre coté : libellé séparé.
    expect(
      requiresLabelFieldFor(
        AssetClass.metauxPrecieux,
        accountEnvelope: AccountEnvelope.cto,
      ),
      isTrue,
    );
    expect(requiresLabelFieldFor(AssetClass.actionsEtFonds), isTrue);
  });
}
