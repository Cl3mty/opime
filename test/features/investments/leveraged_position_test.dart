import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/leveraged_position.dart';

void main() {
  group('round-trip JSON', () {
    test('tous les champs renseignés survivent au round-trip', () {
      final position = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.short,
        leverage: 5,
        size: 0.5,
        entryPrice: 60000,
        markPrice: 58000,
        markPriceAt: DateTime(2026, 1, 15),
        liquidationPrice: 70000,
        cumulativeFunding: -12.5,
        takeProfit: 50000,
        stopLoss: 65000,
        openedAt: DateTime(2026, 1, 1),
        note: 'Couverture portefeuille',
      );
      final decoded = LeveragedPosition.fromJson(position.toJson());

      expect(decoded.id, position.id);
      expect(decoded.market, 'BTC');
      expect(decoded.side, PositionSide.short);
      expect(decoded.leverage, 5);
      expect(decoded.size, 0.5);
      expect(decoded.entryPrice, 60000);
      expect(decoded.margin, 6000);
      expect(decoded.markPrice, 58000);
      expect(decoded.markPriceAt, DateTime(2026, 1, 15));
      expect(decoded.liquidationPrice, 70000);
      expect(decoded.cumulativeFunding, -12.5);
      expect(decoded.takeProfit, 50000);
      expect(decoded.stopLoss, 65000);
      expect(decoded.openedAt, DateTime(2026, 1, 1));
      expect(decoded.note, 'Couverture portefeuille');
      expect(decoded.closedAt, isNull);
      expect(decoded.closePrice, isNull);
    });

    test(
      'champs facultatifs absents : clés omises du JSON, restent null au '
      'décodage',
      () {
        final position = LeveragedPosition(
          market: 'ETH',
          side: PositionSide.long,
          leverage: 2,
          size: 1,
          entryPrice: 3000,
          openedAt: DateTime(2026, 1, 1),
        );
        final json = position.toJson();
        expect(json.containsKey('markPrice'), isFalse);
        expect(json.containsKey('liquidationPrice'), isFalse);
        expect(json.containsKey('takeProfit'), isFalse);
        expect(json.containsKey('stopLoss'), isFalse);
        expect(json.containsKey('closedAt'), isFalse);
        expect(json.containsKey('note'), isFalse);

        final decoded = LeveragedPosition.fromJson(json);
        expect(decoded.markPrice, isNull);
        expect(decoded.liquidationPrice, isNull);
        expect(decoded.takeProfit, isNull);
        expect(decoded.stopLoss, isNull);
        expect(decoded.closedAt, isNull);
        expect(decoded.note, isNull);
      },
    );

    test('position fermée : closedAt/closePrice survivent au round-trip', () {
      final position = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.01,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
        closedAt: DateTime(2026, 2, 1),
        closePrice: 65000,
      );
      final decoded = LeveragedPosition.fromJson(position.toJson());
      expect(decoded.isOpen, isFalse);
      expect(decoded.closedAt, DateTime(2026, 2, 1));
      expect(decoded.closePrice, 65000);
    });
  });

  group('entryPriceCurrency / entryPriceFxRateToEur', () {
    test('round-trip JSON', () {
      final position = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 55000,
        entryPriceCurrency: 'USDC',
        entryPriceFxRateToEur: 0.92,
        openedAt: DateTime(2026, 1, 1),
      );
      final decoded = LeveragedPosition.fromJson(position.toJson());
      expect(decoded.entryPriceCurrency, 'USDC');
      expect(decoded.entryPriceFxRateToEur, 0.92);
    });

    test('absent du JSON : "EUR" par défaut, aucun taux', () {
      final position = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      final json = position.toJson();
      expect(json['entryPriceCurrency'], 'EUR');
      expect(json.containsKey('entryPriceFxRateToEur'), isFalse);

      final decoded = LeveragedPosition.fromJson({
        'market': 'BTC',
        'side': 'long',
        'leverage': 2,
        'size': 0.1,
        'entryPrice': 60000,
        'margin': 3000,
      });
      expect(decoded.entryPriceCurrency, 'EUR');
      expect(decoded.entryPriceFxRateToEur, isNull);
    });

    test('entryPriceInEur convertit un prix d\'entrée en devise étrangère '
        'au taux enregistré, reste tel quel en EUR', () {
      final eur = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(eur.entryPriceInEur, 60000);

      final usdc = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        entryPriceCurrency: 'USDC',
        entryPriceFxRateToEur: 0.92,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(usdc.entryPriceInEur, closeTo(55200, 0.001)); // 60000 * 0.92
    });

    test('pnl/riskRewardRatio utilisent entryPriceInEur, pas entryPrice brut '
        'quand la devise n\'est pas l\'euro', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        // Entrée à 60000 USDC ≈ 55200 € — le PnL doit se calculer contre ce
        // montant converti, pas contre 60000 tel quel.
        entryPrice: 60000,
        entryPriceCurrency: 'USDC',
        entryPriceFxRateToEur: 0.92,
        markPrice: 66000, // déjà en euros (cours crypto auto-résolu)
        takeProfit: 70000,
        stopLoss: 50000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.pnl, closeTo((66000 - 55200) * 0.1, 0.001));
      expect(
        p.riskRewardRatio,
        closeTo((70000 - 55200).abs() / (55200 - 50000).abs(), 0.001),
      );
    });
  });

  group('isMarkPriceFresh', () {
    test('true si markPriceAt tombe aujourd\'hui', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        markPriceAt: DateTime.now(),
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.isMarkPriceFresh, isTrue);
    });

    test('false sans markPriceAt, ou daté d\'un autre jour', () {
      final neverRefreshed = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(neverRefreshed.isMarkPriceFresh, isFalse);

      final stale = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        markPriceAt: DateTime(2020, 1, 1),
        openedAt: DateTime(2026, 1, 1),
      );
      expect(stale.isMarkPriceFresh, isFalse);
    });
  });

  group('margin / entryNotionalValue (calcul automatique, plus de saisie '
      'manuelle — voir la doc de tête de la classe)', () {
    test('margin = taille × prix d\'entrée ÷ levier', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 4,
        size: 0.2,
        entryPrice: 50000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.entryNotionalValue, 10000); // 0.2 * 50000
      expect(p.margin, 2500); // 10000 / 4
    });

    test('entryNotionalValue et margin utilisent entryPriceInEur (converti '
        'depuis une devise étrangère), pas entryPrice brut', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        entryPriceCurrency: 'USDC',
        entryPriceFxRateToEur: 0.92,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.entryNotionalValue, closeTo(5520, 0.001)); // 0.1 * 55200
      expect(p.margin, closeTo(2760, 0.001)); // 5520 / 2
    });

    test('margin vaut 0 si le levier est nul ou négatif (dégénéré, ne '
        'devrait jamais arriver via le formulaire)', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 0,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.margin, 0);
    });
  });

  group('estimatedLiquidationPrice / effectiveLiquidationPrice (calcul '
      'automatique, marge isolée sans marge de maintenance)', () {
    test('long : entrée × (1 - 1/levier)', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 4,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.estimatedLiquidationPrice, 45000); // 60000 * (1 - 1/4)
    });

    test('short : entrée × (1 + 1/levier)', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.short,
        leverage: 4,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.estimatedLiquidationPrice, 75000); // 60000 * (1 + 1/4)
    });

    test(
      'effectiveLiquidationPrice retombe sur l\'estimation tant '
      'qu\'aucune valeur exacte n\'a été saisie à la main, puis utilise '
      'cette dernière une fois renseignée',
      () {
        final estimated = LeveragedPosition(
          market: 'BTC',
          side: PositionSide.long,
          leverage: 2,
          size: 0.1,
          entryPrice: 60000,
          openedAt: DateTime(2026, 1, 1),
        );
        expect(estimated.effectiveLiquidationPrice, 30000);

        final corrected = estimated.copyWith(liquidationPrice: 28500);
        expect(corrected.effectiveLiquidationPrice, 28500);
      },
    );

    test('null si le levier est nul ou négatif', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 0,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.estimatedLiquidationPrice, isNull);
      expect(p.effectiveLiquidationPrice, isNull);
    });
  });

  group('pnl / roePercent', () {
    test('long gagnant : cours au-dessus de l\'entrée', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.pnl, 600); // (66000-60000) * 0.1
      expect(p.roePercent, 20); // 600 / 3000 * 100
    });

    test('long perdant : cours en dessous de l\'entrée', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 54000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.pnl, -600);
      expect(p.roePercent, -20);
    });

    test(
      'short gagnant : cours en dessous de l\'entrée (inverse du long)',
      () {
        final p = LeveragedPosition(
          market: 'BTC',
          side: PositionSide.short,
          leverage: 2,
          size: 0.1,
          entryPrice: 60000,
          markPrice: 54000,
          openedAt: DateTime(2026, 1, 1),
        );
        expect(p.pnl, 600);
        expect(p.roePercent, 20);
      },
    );

    test('short perdant : cours au-dessus de l\'entrée', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.short,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.pnl, -600);
      expect(p.roePercent, -20);
    });

    test('sans cours actualisé : pnl/roePercent restent null', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.pnl, isNull);
      expect(p.roePercent, isNull);
    });

    test(
      'marge nulle (dégénéré : prix d\'entrée nul, ne devrait jamais '
      'arriver via le formulaire, qui l\'exige positif) : roePercent '
      'reste null (pas de division par 0)',
      () {
        final p = LeveragedPosition(
          market: 'BTC',
          side: PositionSide.long,
          leverage: 2,
          size: 0.1,
          entryPrice: 0,
          markPrice: 66000,
          openedAt: DateTime(2026, 1, 1),
        );
        expect(p.margin, 0);
        expect(p.pnl, isNotNull);
        expect(p.roePercent, isNull);
      },
    );

    test('position fermée : pnl/roePercent dérivés de closePrice, figés', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        // markPrice a bougé depuis, mais n'a plus d'effet une fois fermée.
        markPrice: 100000,
        openedAt: DateTime(2026, 1, 1),
        closedAt: DateTime(2026, 2, 1),
        closePrice: 66000,
      );
      expect(p.pnl, 600);
      expect(p.roePercent, 20);
    });
  });

  group('displayValue (valeur comptée dans le patrimoine)', () {
    test('position ouverte : marge + PnL latent', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.displayValue, 3600); // 3000 + 600
    });

    test('position fermée : toujours 0, quel que soit le PnL réalisé', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        openedAt: DateTime(2026, 1, 1),
        closedAt: DateTime(2026, 2, 1),
        closePrice: 66000,
      );
      expect(p.displayValue, 0);
    });
  });

  group('liquidationDistancePercent', () {
    test('écart en % entre le cours actuel et le prix de liquidation', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 100,
        liquidationPrice: 80,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.liquidationDistancePercent, 20); // |100-80|/100 * 100
    });

    test(
      'sans prix de liquidation saisi à la main, retombe sur '
      'l\'estimation calculée (effectiveLiquidationPrice), pas null',
      () {
        final p = LeveragedPosition(
          market: 'BTC',
          side: PositionSide.long,
          leverage: 2,
          size: 0.1,
          entryPrice: 60000,
          markPrice: 45000,
          openedAt: DateTime(2026, 1, 1),
        );
        // Estimation (marge isolée) : 60000 * (1 - 1/2) = 30000.
        expect(p.estimatedLiquidationPrice, 30000);
        expect(p.liquidationPrice, isNull);
        expect(p.effectiveLiquidationPrice, 30000);
        // |45000-30000| / 45000 * 100.
        expect(
          p.liquidationDistancePercent,
          closeTo((45000 - 30000) / 45000 * 100, 0.001),
        );
      },
    );

    test('null pour une position fermée (plus de risque de liquidation)', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 100,
        liquidationPrice: 80,
        openedAt: DateTime(2026, 1, 1),
        closedAt: DateTime(2026, 2, 1),
        closePrice: 100,
      );
      expect(p.liquidationDistancePercent, isNull);
    });
  });

  group('riskRewardRatio', () {
    test('ratio classique |TP - entrée| / |entrée - SL|', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 100,
        takeProfit: 130,
        stopLoss: 90,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.riskRewardRatio, 3); // 30 / 10
    });

    test('null si un seul des deux (TP ou SL) est renseigné', () {
      final onlyTp = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 100,
        takeProfit: 130,
        openedAt: DateTime(2026, 1, 1),
      );
      final onlySl = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 100,
        stopLoss: 90,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(onlyTp.riskRewardRatio, isNull);
      expect(onlySl.riskRewardRatio, isNull);
    });

    test('null si aucun des deux n\'est renseigné', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 100,
        openedAt: DateTime(2026, 1, 1),
      );
      expect(p.riskRewardRatio, isNull);
    });
  });

  group('copyWith', () {
    test('efface un champ nullable explicitement (sentinelle _unset)', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        openedAt: DateTime(2026, 1, 1),
      );
      final cleared = p.copyWith(markPrice: null);
      expect(cleared.markPrice, isNull);
      // Les autres champs ne bougent pas.
      expect(cleared.market, 'BTC');
      expect(cleared.entryPrice, 60000);
    });

    test('paramètre omis : conserve la valeur existante', () {
      final p = LeveragedPosition(
        market: 'BTC',
        side: PositionSide.long,
        leverage: 2,
        size: 0.1,
        entryPrice: 60000,
        markPrice: 66000,
        openedAt: DateTime(2026, 1, 1),
      );
      final updated = p.copyWith(stopLoss: 55000);
      expect(updated.markPrice, 66000);
      expect(updated.entryPrice, 60000);
      expect(updated.stopLoss, 55000);
    });

    test(
      'margin n\'est plus un paramètre : toujours recalculée depuis '
      'taille/prix d\'entrée/levier, y compris après un copyWith qui '
      'change l\'un de ces trois',
      () {
        final p = LeveragedPosition(
          market: 'BTC',
          side: PositionSide.long,
          leverage: 2,
          size: 0.1,
          entryPrice: 60000,
          openedAt: DateTime(2026, 1, 1),
        );
        expect(p.margin, 3000); // 0.1 * 60000 / 2

        final doubledLeverage = p.copyWith(leverage: 4);
        expect(doubledLeverage.margin, 1500); // 0.1 * 60000 / 4
      },
    );
  });
}
