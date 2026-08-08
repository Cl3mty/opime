import 'package:flutter_test/flutter_test.dart';
import 'package:freenary/core/profiles/profile_models.dart';

void main() {
  group('Profile.initials', () {
    test('un seul prénom -> une lettre', () {
      final profile = Profile(id: '1', name: 'Marie', relationship: 'Vous', isMaster: true, createdAt: DateTime.now());
      expect(profile.initials, 'M');
    });

    test('prénom + nom -> deux lettres', () {
      final profile = Profile(id: '1', name: 'Jean Dupont', relationship: 'Vous', isMaster: true, createdAt: DateTime.now());
      expect(profile.initials, 'JD');
    });

    test('espaces multiples sont ignorés', () {
      final profile = Profile(id: '1', name: '  Ana   Silva  ', relationship: '', isMaster: false, createdAt: DateTime.now());
      expect(profile.initials, 'AS');
    });

    test('nom vide -> point d\'interrogation', () {
      final profile = Profile(id: '1', name: '', relationship: '', isMaster: false, createdAt: DateTime.now());
      expect(profile.initials, '?');
    });
  });

  group('Profile — JSON', () {
    test('round-trip', () {
      final profile = Profile(
        id: 'abc',
        name: 'Marie',
        relationship: 'Conjointe',
        isMaster: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final restored = Profile.fromJson(profile.toJson());
      expect(restored.id, 'abc');
      expect(restored.name, 'Marie');
      expect(restored.relationship, 'Conjointe');
      expect(restored.isMaster, false);
      expect(restored.createdAt, profile.createdAt);
    });

    test('copyWith conserve id/isMaster/createdAt', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final profile = Profile(id: 'abc', name: 'Marie', relationship: 'Vous', isMaster: true, createdAt: createdAt);
      final updated = profile.copyWith(name: 'Marie D.');
      expect(updated.id, 'abc');
      expect(updated.isMaster, true);
      expect(updated.createdAt, createdAt);
      expect(updated.name, 'Marie D.');
    });
  });
}
