// Conversion d'unités – module 3.6
//
// STRATÉGIE ANTI-ARRONDI :
// Toutes les opérations arithmétiques transitent par des entiers (µg ou µL),
// soit une précision de 10⁻⁶ kg / 10⁻⁶ L.
// La base interne est le microgramme (µg) pour la masse et le microlitre (µL)
// pour le volume, stockés en int.
// Les doubles SQLite sont convertis en base entière AVANT tout calcul, puis
// reconvertis en double APRÈS, uniquement pour l'affichage ou l'écriture en BDD.
// Ainsi 0.1 + 0.2 = 0.3 exact (100_000 µg + 200_000 µg = 300_000 µg = 0.3 g).
//
// Unités supportées :
//   Masse  : 'g'  → 1_000_000 µg/g
//            'kg' → 1_000_000_000 µg/kg
//   Volume : 'mL' → 1_000_000 µL/mL
//            'L'  → 1_000_000_000 µL/L
//   Non convertibles : 'sac', 'unité', tout autre

/// Famille d'unités.
enum UnitFamily { masse, volume, nonConvertible }

class UnitConverter {
  UnitConverter._();

  // ── Facteurs (micro-unités par unité) ─────────────────────────────────────
  static const int _microPerG  = 1000000;          // µg par gramme
  static const int _microPerKg = 1000000000;       // µg par kilogramme
  static const int _microPerMl = 1000000;          // µL par millilitre
  static const int _microPerL  = 1000000000;       // µL par litre

  /// Seuil d'affichage : en dessous, on reste dans la petite unité.
  /// 1000 g → 1 kg ;  1000 mL → 1 L.
  static const double _displayThreshold = 1000.0;

  // ── Famille ────────────────────────────────────────────────────────────────

  /// Retourne la famille de l'unité.
  static UnitFamily familyOf(String unit) => switch (unit) {
        'g' || 'kg' => UnitFamily.masse,
        'mL' || 'L' => UnitFamily.volume,
        _ => UnitFamily.nonConvertible,
      };

  /// Vrai si les deux unités appartiennent à la même famille convertible.
  static bool canConvert(String from, String to) {
    final f = familyOf(from);
    return f != UnitFamily.nonConvertible && f == familyOf(to);
  }

  /// Liste des unités disponibles dans la même famille que [unit].
  /// Retourne [unit] seul si non convertible.
  static List<String> siblingUnits(String unit) => switch (unit) {
        'g' || 'kg' => const ['g', 'kg'],
        'mL' || 'L' => const ['mL', 'L'],
        _ => [unit],
      };

  // ── Conversion vers base micro-unité ───────────────────────────────────────

  /// Convertit [qty] exprimée en [unit] en micro-unités (int).
  /// Lève [ArgumentError] si l'unité est inconnue.
  static int toMicro(double qty, String unit) {
    final factor = _factor(unit);
    // Multiplication via round() pour éviter les dérives float.
    return (qty * factor).round();
  }

  /// Convertit [micro] micro-unités dans [unit].
  static double fromMicro(int micro, String unit) {
    final factor = _factor(unit);
    return micro / factor;
  }

  // ── Conversion directe ────────────────────────────────────────────────────

  /// Convertit [qty] de [fromUnit] vers [toUnit].
  /// Les deux unités doivent appartenir à la même famille.
  /// Lève [ArgumentError] si la conversion est impossible.
  static double convert(double qty, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return qty;
    if (!canConvert(fromUnit, toUnit)) {
      throw ArgumentError(
        'Impossible de convertir "$fromUnit" en "$toUnit" : '
        'familles différentes ou unité non convertible.',
      );
    }
    final micro = toMicro(qty, fromUnit);
    return fromMicro(micro, toUnit);
  }

  // ── Affichage intelligent ─────────────────────────────────────────────────

  /// Retourne la valeur et l'unité dans le format le plus lisible.
  ///
  /// Exemples :
  ///   1500 g   → (1.5, 'kg')
  ///   250  g   → (250.0, 'g')
  ///   0.25 kg  → (250.0, 'g')
  ///   2.5  L   → (2.5, 'L')
  ///   500  mL  → (500.0, 'mL')
  ///   3    sac → (3.0, 'sac')  [inchangé]
  static ({double value, String unit}) smartValue(
    double qty,
    String unit,
  ) {
    final family = familyOf(unit);
    if (family == UnitFamily.nonConvertible) return (value: qty, unit: unit);

    // Normalise tout en petite unité (g ou mL) pour comparer au seuil
    final smallUnit = family == UnitFamily.masse ? 'g' : 'mL';
    final bigUnit   = family == UnitFamily.masse ? 'kg' : 'L';

    final inSmall = convert(qty, unit, smallUnit);

    if (inSmall >= _displayThreshold) {
      return (value: convert(inSmall, smallUnit, bigUnit), unit: bigUnit);
    } else {
      return (value: inSmall, unit: smallUnit);
    }
  }

  /// Version texte de [smartValue] — formatée avec jusqu'à 3 décimales
  /// significatives, sans zéros inutiles.
  ///
  /// Exemples : "1,5 kg",  "250 g",  "2,5 L",  "500 mL",  "3 sac".
  static String smartDisplay(double qty, String unit) {
    final (:value, unit: u) = smartValue(qty, unit);
    return '${_format(value)} $u';
  }

  /// Formate un double sans zéros inutiles, max 3 décimales, séparateur virgule.
  static String _format(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    // Jusqu'à 3 décimales, on retire les zéros finaux
    final s = v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
    // Retire le point final s'il reste
    final cleaned = s.endsWith('.') ? s.substring(0, s.length - 1) : s;
    // Remplace le point décimal par une virgule (convention française)
    return cleaned.replaceAll('.', ',');
  }

  // ── Arrondi selon l'unité ──────────────────────────────────────────────────

  /// Arrondit [qty] (dans [unit]) vers le haut selon la granularité de l'unité.
  ///
  /// - sac / unité → entier supérieur (ceil)
  /// - g / mL       → entier supérieur au gramme/mL
  /// - kg / L       → 3 décimales (précision au gramme / millilitre)
  static double ceilToUnit(double qty, String unit) => switch (unit) {
        'sac' || 'unité' => qty.ceilToDouble(),
        'g'  || 'mL'     => qty.ceilToDouble(),
        'kg' || 'L'      => _roundTo3(qty, ceil: true),
        _ => qty.ceilToDouble(),
      };

  static double _roundTo3(double v, {required bool ceil}) {
    const factor = 1000.0;
    return ceil
        ? (v * factor).ceil() / factor
        : (v * factor).floor() / factor;
  }

  // ── Interne ───────────────────────────────────────────────────────────────

  static int _factor(String unit) => switch (unit) {
        'g'  => _microPerG,
        'kg' => _microPerKg,
        'mL' => _microPerMl,
        'L'  => _microPerL,
        _ => throw ArgumentError('Unité inconnue : "$unit"'),
      };
}
