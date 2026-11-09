// Tests unitaires – Conversion d'unités (fonctionnalité 1)

import 'package:flutter_test/flutter_test.dart';
import 'package:my_application/utils/unit_converter.dart';

void main() {
  // ── familyOf ─────────────────────────────────────────────────────────────
  group('UnitConverter.familyOf', () {
    test('g et kg → masse', () {
      expect(UnitConverter.familyOf('g'),  UnitFamily.masse);
      expect(UnitConverter.familyOf('kg'), UnitFamily.masse);
    });
    test('mL et L → volume', () {
      expect(UnitConverter.familyOf('mL'), UnitFamily.volume);
      expect(UnitConverter.familyOf('L'),  UnitFamily.volume);
    });
    test('sac, unité, inconnu → nonConvertible', () {
      expect(UnitConverter.familyOf('sac'),   UnitFamily.nonConvertible);
      expect(UnitConverter.familyOf('unité'), UnitFamily.nonConvertible);
      expect(UnitConverter.familyOf('boite'), UnitFamily.nonConvertible);
    });
  });

  // ── canConvert ────────────────────────────────────────────────────────────
  group('UnitConverter.canConvert', () {
    test('g ↔ kg → true', () {
      expect(UnitConverter.canConvert('g', 'kg'), isTrue);
      expect(UnitConverter.canConvert('kg', 'g'), isTrue);
    });
    test('mL ↔ L → true', () {
      expect(UnitConverter.canConvert('mL', 'L'), isTrue);
      expect(UnitConverter.canConvert('L', 'mL'), isTrue);
    });
    test('kg ↔ L → false (familles différentes)', () {
      expect(UnitConverter.canConvert('kg', 'L'), isFalse);
    });
    test('sac ↔ sac → false (non convertible)', () {
      expect(UnitConverter.canConvert('sac', 'sac'), isFalse);
    });
    test('même unité → true', () {
      expect(UnitConverter.canConvert('kg', 'kg'), isTrue);
    });
  });

  // ── convert ───────────────────────────────────────────────────────────────
  group('UnitConverter.convert', () {
    test('1 kg → 1000 g', () {
      expect(UnitConverter.convert(1, 'kg', 'g'), equals(1000.0));
    });
    test('1000 g → 1 kg', () {
      expect(UnitConverter.convert(1000, 'g', 'kg'), equals(1.0));
    });
    test('1 L → 1000 mL', () {
      expect(UnitConverter.convert(1, 'L', 'mL'), equals(1000.0));
    });
    test('1000 mL → 1 L', () {
      expect(UnitConverter.convert(1000, 'mL', 'L'), equals(1.0));
    });
    test('même unité → valeur inchangée', () {
      expect(UnitConverter.convert(42, 'kg', 'kg'), equals(42.0));
    });
    test('0,25 kg → 250 g (précision)', () {
      expect(UnitConverter.convert(0.25, 'kg', 'g'), equals(250.0));
    });
    test('conversion inter-famille lève ArgumentError', () {
      expect(
        () => UnitConverter.convert(1, 'kg', 'L'),
        throwsArgumentError,
      );
    });
    test('unité inconnue lève ArgumentError', () {
      expect(
        () => UnitConverter.convert(1, 'kg', 'sac'),
        throwsArgumentError,
      );
    });

    // Cas anti-arrondi flottant (0.1 + 0.2)
    test('100 g + 200 g = 300 g exact (anti-arrondi)', () {
      final a = UnitConverter.toMicro(0.1, 'kg'); // 100_000 µg
      final b = UnitConverter.toMicro(0.2, 'kg'); // 200_000 µg
      final sum = a + b;                           // 300_000 µg exact
      expect(UnitConverter.fromMicro(sum, 'kg'), equals(0.3));
    });
    test('1500 g → 1.5 kg sans dérive float', () {
      final micro = UnitConverter.toMicro(1500, 'g');
      expect(UnitConverter.fromMicro(micro, 'kg'), equals(1.5));
    });
  });

  // ── smartValue ───────────────────────────────────────────────────────────
  group('UnitConverter.smartValue', () {
    test('1500 g → (1.5, kg)', () {
      final r = UnitConverter.smartValue(1500, 'g');
      expect(r.value, equals(1.5));
      expect(r.unit, equals('kg'));
    });
    test('250 g reste en g', () {
      final r = UnitConverter.smartValue(250, 'g');
      expect(r.value, equals(250.0));
      expect(r.unit, equals('g'));
    });
    test('0.25 kg → (250, g)', () {
      final r = UnitConverter.smartValue(0.25, 'kg');
      expect(r.value, equals(250.0));
      expect(r.unit, equals('g'));
    });
    test('2.5 L reste en L', () {
      final r = UnitConverter.smartValue(2.5, 'L');
      expect(r.value, equals(2.5));
      expect(r.unit, equals('L'));
    });
    test('500 mL reste en mL', () {
      final r = UnitConverter.smartValue(500, 'mL');
      expect(r.value, equals(500.0));
      expect(r.unit, equals('mL'));
    });
    test('1000 mL → (1, L)', () {
      final r = UnitConverter.smartValue(1000, 'mL');
      expect(r.value, equals(1.0));
      expect(r.unit, equals('L'));
    });
    test('sac → inchangé (non convertible)', () {
      final r = UnitConverter.smartValue(3, 'sac');
      expect(r.value, equals(3.0));
      expect(r.unit, equals('sac'));
    });
    test('unité inconnue → inchangée', () {
      final r = UnitConverter.smartValue(5, 'boite');
      expect(r.value, equals(5.0));
      expect(r.unit, equals('boite'));
    });
    // Cas limite : exactement 1000 g = seuil → passe en kg
    test('1000 g → (1, kg) — valeur exactement au seuil', () {
      final r = UnitConverter.smartValue(1000, 'g');
      expect(r.value, equals(1.0));
      expect(r.unit, equals('kg'));
    });
    // Cas limite : 999 g reste en g
    test('999 g reste en g', () {
      final r = UnitConverter.smartValue(999, 'g');
      expect(r.value, equals(999.0));
      expect(r.unit, equals('g'));
    });
  });

  // ── smartDisplay ─────────────────────────────────────────────────────────
  group('UnitConverter.smartDisplay', () {
    test('1500 g → "1,5 kg"', () {
      expect(UnitConverter.smartDisplay(1500, 'g'), equals('1,5 kg'));
    });
    test('250 g → "250 g"', () {
      expect(UnitConverter.smartDisplay(250, 'g'), equals('250 g'));
    });
    test('1 kg → "1 kg"', () {
      expect(UnitConverter.smartDisplay(1, 'kg'), equals('1 kg'));
    });
    test('0.25 kg → "250 g"', () {
      expect(UnitConverter.smartDisplay(0.25, 'kg'), equals('250 g'));
    });
    test('3 sac → "3 sac"', () {
      expect(UnitConverter.smartDisplay(3, 'sac'), equals('3 sac'));
    });
    test('0.5 L → "500 mL"', () {
      expect(UnitConverter.smartDisplay(0.5, 'L'), equals('500 mL'));
    });
    test('2500 mL → "2,5 L"', () {
      expect(UnitConverter.smartDisplay(2500, 'mL'), equals('2,5 L'));
    });
  });

  // ── ceilToUnit ───────────────────────────────────────────────────────────
  group('UnitConverter.ceilToUnit', () {
    test('2.3 sac → 3 sac (entier supérieur)', () {
      expect(UnitConverter.ceilToUnit(2.3, 'sac'), equals(3.0));
    });
    test('2.0 sac → 2 sac (exact)', () {
      expect(UnitConverter.ceilToUnit(2.0, 'sac'), equals(2.0));
    });
    test('1.5 unité → 2', () {
      expect(UnitConverter.ceilToUnit(1.5, 'unité'), equals(2.0));
    });
    test('1.4 g → 2 g (ceil au gramme)', () {
      expect(UnitConverter.ceilToUnit(1.4, 'g'), equals(2.0));
    });
    test('1.0015 kg → 1.002 kg (3 décimales)', () {
      expect(UnitConverter.ceilToUnit(1.0015, 'kg'), closeTo(1.002, 0.0001));
    });
  });

  // ── siblingUnits ─────────────────────────────────────────────────────────
  group('UnitConverter.siblingUnits', () {
    test('kg → [g, kg]', () {
      expect(UnitConverter.siblingUnits('kg'), containsAll(['g', 'kg']));
    });
    test('L → [mL, L]', () {
      expect(UnitConverter.siblingUnits('L'), containsAll(['mL', 'L']));
    });
    test('sac → [sac] seul', () {
      expect(UnitConverter.siblingUnits('sac'), equals(['sac']));
    });
  });
}
