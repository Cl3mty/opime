import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/investments/investments_models.dart' show Sector;
import 'package:opime/features/investments/sector_style.dart';

void main() {
  group('sectorColor', () {
    test('une couleur distincte par secteur', () {
      final colors = Sector.values.map(sectorColor).toSet();
      expect(colors, hasLength(Sector.values.length));
    });

    test('non classé (null) : couleur dédiée, distincte de tous les secteurs', () {
      expect(sectorColor(null), unclassifiedSectorColor);
      expect(Sector.values.map(sectorColor), isNot(contains(unclassifiedSectorColor)));
    });
  });

  group('sectorIcon', () {
    test('une icône par secteur (pas forcément distincte, mais définie)', () {
      for (final sector in Sector.values) {
        expect(sectorIcon(sector), isNotNull);
      }
    });
  });
}
