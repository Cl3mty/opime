import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/features/academy/envelopes_data.dart';
import 'package:freenary/features/academy/investissement_data.dart';
import 'package:freenary/features/academy/formation_data.dart';
import 'package:freenary/features/navigation/nav_models.dart';

void main() {
  final allAcademyStepIds = [
    ...investissementCards.map((c) => c.id),
    for (final track in formationTracks) ...track.steps.map((s) => s.id),
  ];

  group('Enveloppes', () {
    test('identifiants uniques', () {
      final ids = envelopes.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('chaque enveloppe a une fiche complète', () {
      for (final envelope in envelopes) {
        expect(envelope.name, isNotEmpty, reason: envelope.id);
        expect(envelope.tagline, isNotEmpty, reason: envelope.id);
        expect(envelope.ceiling, isNotEmpty, reason: envelope.id);
        expect(envelope.taxation, isNotEmpty, reason: envelope.id);
        expect(envelope.liquidity, isNotEmpty, reason: envelope.id);
        expect(envelope.idealFor, isNotEmpty, reason: envelope.id);
        expect(envelope.pitfall, isNotEmpty, reason: envelope.id);
        expect(envelope.goodToKnow, isNotEmpty, reason: envelope.id);
      }
    });

    test('niveau croissant (crescendo simple -> avancé)', () {
      final levels = envelopes.map((e) => e.level.index).toList();
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i], greaterThanOrEqualTo(levels[i - 1]), reason: envelopes[i].id);
      }
    });
  });

  group('Investissement', () {
    test('identifiants uniques', () {
      final ids = investissementCards.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('chaque carte a un titre, une accroche et au moins un point clé', () {
      for (final card in investissementCards) {
        expect(card.title, isNotEmpty, reason: card.id);
        expect(card.tagline, isNotEmpty, reason: card.id);
        expect(card.bullets, isNotEmpty, reason: card.id);
      }
    });

    test('niveau croissant (crescendo simple -> avancé)', () {
      final levels = investissementCards.map((c) => c.level.index).toList();
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i], greaterThanOrEqualTo(levels[i - 1]), reason: investissementCards[i].id);
      }
    });
  });

  group('Formation', () {
    test('identifiants de parcours uniques', () {
      final ids = formationTracks.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('chaque parcours a au moins une leçon', () {
      for (final track in formationTracks) {
        expect(track.steps, isNotEmpty, reason: track.id);
      }
    });

    test('le niveau d\'un parcours correspond au niveau le plus élevé de ses leçons', () {
      for (final track in formationTracks) {
        final expected = track.steps.map((s) => s.level.index).reduce((a, b) => a > b ? a : b);
        expect(track.level.index, expected, reason: track.id);
      }
    });

    test('le parcours "Lire les comptes" explique ses termes techniques en contexte', () {
      final track = formationTracks.firstWhere((t) => t.id == 'formation_comptes');
      for (final step in track.steps) {
        expect(step.vocabulary, isNotEmpty, reason: step.id);
      }
    });
  });

  test('tous les identifiants de notions sont uniques (clé de progression partagée)', () {
    expect(allAcademyStepIds.toSet().length, allAcademyStepIds.length);
  });

  test('les identifiants d\'enveloppes et de notions ne se chevauchent pas', () {
    final envelopeIds = envelopes.map((e) => e.id).toSet();
    expect(envelopeIds.intersection(allAcademyStepIds.toSet()), isEmpty);
  });

  group('Navigation sidebar', () {
    NavItem findChild(String parentKey) => academieGroup.items.firstWhere((i) => i.key == parentKey);

    test('les sous-items "Enveloppes" correspondent exactement aux enveloppes définies', () {
      final navKeys = findChild('enveloppes').children.map((c) => c.key).toSet();
      final contentKeys = envelopes.map((e) => e.id).toSet();
      expect(navKeys, contentKeys);
    });

    test('les sous-items "Investissement" correspondent exactement aux cartes définies', () {
      final navKeys = findChild('investissement').children.map((c) => c.key).toSet();
      final contentKeys = investissementCards.map((c) => c.id).toSet();
      expect(navKeys, contentKeys);
    });

    test('les sous-items "Formation" correspondent exactement aux parcours définis', () {
      final navKeys = findChild('formation').children.map((c) => c.key).toSet();
      final contentKeys = formationTracks.map((t) => t.id).toSet();
      expect(navKeys, contentKeys);
    });
  });
}
