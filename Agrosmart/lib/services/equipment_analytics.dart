import 'dart:math' as math;

import '../models/maintenance_record.dart';
import '../models/materiel.dart';

/// How close the next maintenance of an equipment is.
enum MaintenanceUrgency {
  overdue('En retard'),
  soon('Bientôt'),
  planned('Planifiée');

  const MaintenanceUrgency(this.label);

  final String label;
}

/// Fuel used by the whole fleet during one calendar month.
class MonthlyFuel {
  const MonthlyFuel({
    required this.month,
    required this.litres,
    required this.cost,
  });

  /// First day of the month.
  final DateTime month;
  final double litres;
  final double cost;
}

/// Statistics, maintenance forecast and lifespan estimate of one equipment,
/// computed locally from its fuel, maintenance and labour entries.
class EquipmentStats {
  const EquipmentStats({
    required this.materiel,
    required this.fuelLitres,
    required this.fuelCost,
    required this.fuelEntries,
    required this.monthlyLitres,
    required this.litresLast30Days,
    required this.trendPercent,
    required this.pricePerLitre,
    required this.maintenanceCount,
    required this.maintenanceCost,
    required this.lastMaintenance,
    required this.maintenanceIntervalDays,
    required this.intervalFromHistory,
    required this.nextMaintenance,
    required this.urgency,
    required this.laborHours,
    required this.laborCost,
    required this.ageYears,
    required this.expectedLifeYears,
    required this.remainingLifeYears,
  });

  final Materiel materiel;

  final double fuelLitres;
  final double fuelCost;
  final int fuelEntries;

  /// Average litres per month since the first fuel entry.
  final double monthlyLitres;
  final double litresLast30Days;

  /// Last 30 days compared to the earlier monthly average, in %. `null` when
  /// there is not enough history to compare.
  final double? trendPercent;

  /// Average price paid per litre, `null` without litres.
  final double? pricePerLitre;

  final int maintenanceCount;
  final double maintenanceCost;
  final DateTime? lastMaintenance;

  /// Days between two maintenances.
  final int maintenanceIntervalDays;

  /// `true` when [maintenanceIntervalDays] comes from the equipment's own
  /// history, `false` when it is the default of its category.
  final bool intervalFromHistory;
  final DateTime nextMaintenance;
  final MaintenanceUrgency urgency;

  final double laborHours;
  final double laborCost;

  final double ageYears;
  final double expectedLifeYears;
  final double remainingLifeYears;

  double get totalCost => fuelCost + maintenanceCost + laborCost;

  /// Share of the expected life already used, between 0 and 1.
  double get lifeUsed => expectedLifeYears <= 0
      ? 1
      : (ageYears / expectedLifeYears).clamp(0, 1).toDouble();

  int daysUntilMaintenance(DateTime now) =>
      _day(nextMaintenance).difference(_day(now)).inDays;

  /// Compact summary sent to the AI.
  Map<String, dynamic> toAiJson(DateTime now) => {
    'nom': materiel.name,
    'categorie': materiel.category.label,
    'marque_modele': '${materiel.brand} ${materiel.model}'.trim(),
    'date_achat': _isoDay(materiel.purchaseDate),
    'prix_achat_dt': _round(materiel.purchasePrice),
    'etat': materiel.condition.label,
    'statut': materiel.status.label,
    'age_ans': _round(ageYears),
    'carburant': {
      'litres_total': _round(fuelLitres),
      'cout_total_dt': _round(fuelCost),
      'pleins': fuelEntries,
      'litres_par_mois': _round(monthlyLitres),
      'litres_30_derniers_jours': _round(litresLast30Days),
      'tendance_pct': trendPercent == null ? null : _round(trendPercent!),
      'prix_moyen_litre_dt': pricePerLitre == null
          ? null
          : _round(pricePerLitre!),
    },
    'maintenance': {
      'nombre': maintenanceCount,
      'cout_total_dt': _round(maintenanceCost),
      'derniere': lastMaintenance == null ? null : _isoDay(lastMaintenance!),
      'intervalle_jours': maintenanceIntervalDays,
      'prochaine_estimee': _isoDay(nextMaintenance),
      'jours_restants': daysUntilMaintenance(now),
    },
    'main_oeuvre': {
      'heures': _round(laborHours),
      'cout_total_dt': _round(laborCost),
    },
    'duree_vie_estimee_ans': _round(expectedLifeYears),
    'duree_vie_restante_ans': _round(remainingLifeYears),
  };
}

/// Statistics of the whole fleet of equipment.
class FleetAnalytics {
  const FleetAnalytics({
    required this.equipments,
    required this.monthlyFuel,
    required this.generatedAt,
  });

  final List<EquipmentStats> equipments;

  /// The last 12 months, oldest first, including empty months.
  final List<MonthlyFuel> monthlyFuel;
  final DateTime generatedAt;

  double get totalLitres => equipments.fold(0, (s, e) => s + e.fuelLitres);
  double get totalFuelCost => equipments.fold(0, (s, e) => s + e.fuelCost);
  double get totalMaintenanceCost =>
      equipments.fold(0, (s, e) => s + e.maintenanceCost);
  double get totalLaborCost => equipments.fold(0, (s, e) => s + e.laborCost);
  double get monthlyLitres => equipments.fold(0, (s, e) => s + e.monthlyLitres);

  /// Equipment whose maintenance is overdue or due within 30 days.
  int get maintenancesDue =>
      equipments.where((e) => e.urgency != MaintenanceUrgency.planned).length;

  bool get hasRecords => equipments.any(
    (e) => e.fuelEntries + e.maintenanceCount > 0 || e.laborHours > 0,
  );

  /// Default life (years) of each category, before wear adjustments.
  static const baseLifeYears = {
    MaterielCategory.soil: 12.0,
    MaterielCategory.planting: 10.0,
    MaterielCategory.harvest: 15.0,
  };

  /// Default days between two maintenances when the history is too short.
  static const defaultIntervalDays = {
    MaterielCategory.soil: 120,
    MaterielCategory.planting: 90,
    MaterielCategory.harvest: 150,
  };

  /// A maintenance within this many days is "soon".
  static const soonThresholdDays = 30;

  static FleetAnalytics compute(
    List<Materiel> materiels,
    List<MaintenanceRecord> records, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final byMateriel = <String, List<MaintenanceRecord>>{};
    for (final r in records) {
      byMateriel.putIfAbsent(r.materielId, () => []).add(r);
    }

    // First pass: fuel per equipment, needed for the fleet average usage.
    final monthly = {
      for (final m in materiels)
        m.id: _monthlyLitres(
          (byMateriel[m.id] ?? const [])
              .where((r) => r.type == MaintenanceRecordType.fuel)
              .toList(),
          today,
        ),
    };
    final users = monthly.values.where((v) => v > 0).toList();
    final fleetAverage = users.isEmpty
        ? 0.0
        : users.reduce((a, b) => a + b) / users.length;

    final stats = [
      for (final m in materiels)
        _equipmentStats(
          m,
          byMateriel[m.id] ?? const [],
          monthly[m.id]!,
          fleetAverage,
          today,
        ),
    ];

    return FleetAnalytics(
      equipments: stats,
      monthlyFuel: _lastTwelveMonths(records, today),
      generatedAt: today,
    );
  }

  /// Summary sent to the AI.
  Map<String, dynamic> toAiJson() => {
    'date_analyse': _isoDay(generatedAt),
    'devise': 'DT (dinar tunisien)',
    'totaux': {
      'litres_carburant': _round(totalLitres),
      'cout_carburant_dt': _round(totalFuelCost),
      'cout_maintenance_dt': _round(totalMaintenanceCost),
      'cout_main_oeuvre_dt': _round(totalLaborCost),
      'litres_par_mois': _round(monthlyLitres),
    },
    'carburant_par_mois': [
      for (final m in monthlyFuel)
        {
          'mois': '${m.month.year}-${m.month.month.toString().padLeft(2, '0')}',
          'litres': _round(m.litres),
          'cout_dt': _round(m.cost),
        },
    ],
    'materiels': [for (final e in equipments) e.toAiJson(generatedAt)],
  };
}

EquipmentStats _equipmentStats(
  Materiel m,
  List<MaintenanceRecord> records,
  double monthlyLitres,
  double fleetAverageLitres,
  DateTime now,
) {
  final fuel = records.where((r) => r.type == MaintenanceRecordType.fuel);
  final maintenances =
      records.where((r) => r.type == MaintenanceRecordType.maintenance).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  final labor = records.where((r) => r.type == MaintenanceRecordType.labor);

  final fuelLitres = fuel.fold(0.0, (s, r) => s + (r.quantity ?? 0));
  final fuelCost = fuel.fold(0.0, (s, r) => s + r.cost);

  // Trend: last 30 days against the monthly average of the older entries.
  final cutoff = now.subtract(const Duration(days: 30));
  final recent = fuel
      .where((r) => r.date.isAfter(cutoff))
      .fold(0.0, (s, r) => s + (r.quantity ?? 0));
  final older = fuel.where((r) => !r.date.isAfter(cutoff)).toList();
  double? trend;
  if (older.isNotEmpty) {
    final olderAverage = _monthlyLitres(older, cutoff);
    if (olderAverage > 0) trend = (recent - olderAverage) / olderAverage * 100;
  }

  // Maintenance interval: the equipment's own rhythm when known.
  final category = m.category;
  var interval = FleetAnalytics.defaultIntervalDays[category]!;
  var fromHistory = false;
  if (maintenances.length >= 2) {
    final span = maintenances.last.date
        .difference(maintenances.first.date)
        .inDays;
    if (span > 0) {
      interval = (span / (maintenances.length - 1)).round().clamp(7, 730);
      fromHistory = true;
    }
  }
  // Heavy users and worn equipment need servicing more often.
  if (fleetAverageLitres > 0 && monthlyLitres > fleetAverageLitres * 1.3) {
    interval = (interval * .85).round();
  }
  if (m.condition == MaterielCondition.worn) interval = (interval * .8).round();

  final last = maintenances.isEmpty ? null : maintenances.last.date;
  var next = (last ?? m.purchaseDate).add(Duration(days: interval));
  final broken =
      m.condition == MaterielCondition.broken ||
      m.status == MaterielStatus.outOfService;
  if (broken && next.isAfter(now)) next = now;
  final days = _day(next).difference(_day(now)).inDays;
  final urgency = days < 0 || broken
      ? MaintenanceUrgency.overdue
      : days <= FleetAnalytics.soonThresholdDays
      ? MaintenanceUrgency.soon
      : MaintenanceUrgency.planned;

  // Lifespan: category default adjusted by condition, usage and repairs.
  final age = math.max(0, now.difference(m.purchaseDate).inDays) / 365.25;
  final conditionFactor = switch (m.condition) {
    MaterielCondition.newItem => 1.0,
    MaterielCondition.good => .95,
    MaterielCondition.worn => .75,
    MaterielCondition.broken => .55,
  };
  final usageRatio = fleetAverageLitres > 0
      ? monthlyLitres / fleetAverageLitres
      : 1.0;
  final usageFactor = (1.15 - .15 * usageRatio).clamp(.7, 1.15);
  final maintenanceCost = maintenances.fold(0.0, (s, r) => s + r.cost);
  final repairRatio = m.purchasePrice > 0
      ? maintenanceCost / m.purchasePrice
      : 0.0;
  final repairFactor = repairRatio > .6
      ? .8
      : repairRatio > .3
      ? .9
      : 1.0;
  final expected =
      FleetAnalytics.baseLifeYears[category]! *
      conditionFactor *
      usageFactor *
      repairFactor;

  return EquipmentStats(
    materiel: m,
    fuelLitres: fuelLitres,
    fuelCost: fuelCost,
    fuelEntries: fuel.length,
    monthlyLitres: monthlyLitres,
    litresLast30Days: recent,
    trendPercent: trend,
    pricePerLitre: fuelLitres > 0 ? fuelCost / fuelLitres : null,
    maintenanceCount: maintenances.length,
    maintenanceCost: maintenanceCost,
    lastMaintenance: last,
    maintenanceIntervalDays: interval,
    intervalFromHistory: fromHistory,
    nextMaintenance: next,
    urgency: urgency,
    laborHours: labor.fold(0.0, (s, r) => s + (r.quantity ?? 0)),
    laborCost: labor.fold(0.0, (s, r) => s + r.cost),
    ageYears: age,
    expectedLifeYears: expected,
    remainingLifeYears: math.max(0, expected - age),
  );
}

/// Litres per month from the first fill up to [until] (at least one month).
double _monthlyLitres(List<MaintenanceRecord> fuel, DateTime until) {
  if (fuel.isEmpty) return 0;
  final first = fuel.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
  final months = math.max(1.0, until.difference(first).inDays / 30.44);
  return fuel.fold(0.0, (s, r) => s + (r.quantity ?? 0)) / months;
}

List<MonthlyFuel> _lastTwelveMonths(
  List<MaintenanceRecord> records,
  DateTime now,
) {
  final months = [
    for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
  ];
  final litres = List.filled(12, 0.0);
  final cost = List.filled(12, 0.0);
  for (final r in records) {
    if (r.type != MaintenanceRecordType.fuel) continue;
    final index = months.indexWhere(
      (m) => m.year == r.date.year && m.month == r.date.month,
    );
    if (index < 0) continue;
    litres[index] += r.quantity ?? 0;
    cost[index] += r.cost;
  }
  return [
    for (var i = 0; i < 12; i++)
      MonthlyFuel(month: months[i], litres: litres[i], cost: cost[i]),
  ];
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

double _round(double v) => (v * 100).roundToDouble() / 100;
