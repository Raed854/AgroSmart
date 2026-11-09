import 'package:flutter/material.dart';

import '../main.dart';
import '../models/maintenance_record.dart';
import '../models/materiel.dart';
import '../services/ai_analytics_service.dart';
import '../services/equipment_analytics.dart';
import '../services/maintenance_repository.dart';
import '../services/materiel_repository.dart';
import 'maintenance_screen.dart' show maintenanceTypeColor;

const _months = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Juin',
  'Juil',
  'Août',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _num(double v, [int digits = 1]) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(digits);

Color _urgencyColor(MaintenanceUrgency u) => switch (u) {
  MaintenanceUrgency.overdue => const Color(0xFFC62828),
  MaintenanceUrgency.soon => const Color(0xFFEF6C00),
  MaintenanceUrgency.planned => forestGreen,
};

Color _priorityColor(String p) => switch (p.toLowerCase()) {
  'haute' => const Color(0xFFC62828),
  'moyenne' => const Color(0xFFEF6C00),
  _ => forestGreen,
};

/// Fuel statistics, consumption analysis, maintenance forecast and lifespan
/// estimate of the farm equipment, with an optional Gemini analysis.
class EquipmentAnalyticsScreen extends StatefulWidget {
  const EquipmentAnalyticsScreen({
    super.key,
    this.materielRepository,
    this.maintenanceRepository,
    this.aiService,
  });

  final MaterielRepository? materielRepository;
  final MaintenanceRepository? maintenanceRepository;
  final AiAnalyticsService? aiService;

  @override
  State<EquipmentAnalyticsScreen> createState() =>
      _EquipmentAnalyticsScreenState();
}

class _EquipmentAnalyticsScreenState extends State<EquipmentAnalyticsScreen> {
  late final MaterielRepository _materiels =
      widget.materielRepository ?? SqfliteMaterielRepository();
  late final MaintenanceRepository _records =
      widget.maintenanceRepository ?? SqfliteMaintenanceRepository();
  late final AiAnalyticsService _ai = widget.aiService ?? AiAnalyticsService();

  FleetAnalytics? _analytics;
  bool _loadFailed = false;

  AiFleetReport? _report;
  String? _aiError;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _materiels.fetchMateriels(),
        _records.fetchAllRecords(),
      ]);
      if (!mounted) return;
      setState(() {
        _analytics = FleetAnalytics.compute(
          results[0] as List<Materiel>,
          results[1] as List<MaintenanceRecord>,
        );
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _runAi() async {
    final analytics = _analytics;
    if (analytics == null || _aiLoading) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final report = await _ai.analyse(analytics);
      if (mounted) setState(() => _report = report);
    } on AiAnalyticsException catch (e) {
      if (mounted) setState(() => _aiError = e.message);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Statistiques & IA',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const Text(
                'Carburant, consommations, prochaines maintenances et durée '
                'de vie estimée de vos matériels.',
              ),
              const SizedBox(height: 16),
              if (_loadFailed)
                const _Empty(
                  icon: Icons.error_outline,
                  text: 'Impossible de charger les statistiques.',
                )
              else if (analytics == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (analytics.equipments.isEmpty)
                const _Empty(
                  icon: Icons.inventory_2_outlined,
                  text:
                      'Aucun matériel enregistré.\n'
                      'Ajoutez-en depuis la page « Matériels ».',
                )
              else
                ..._content(analytics),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(FleetAnalytics a) {
    final now = a.generatedAt;
    final byFuel = [...a.equipments]
      ..sort((x, y) => y.fuelLitres.compareTo(x.fuelLitres));
    final byMaintenance = [...a.equipments]
      ..sort((x, y) => x.nextMaintenance.compareTo(y.nextMaintenance));
    final byLife = [...a.equipments]
      ..sort((x, y) => x.remainingLifeYears.compareTo(y.remainingLifeYears));

    return [
      _KpiGrid(analytics: a),
      const SizedBox(height: 16),
      _AiCard(
        configured: _ai.isConfigured,
        loading: _aiLoading,
        error: _aiError,
        report: _report,
        onRun: _runAi,
      ),
      const SizedBox(height: 20),
      const _SectionTitle('Carburant par mois (12 derniers mois)'),
      _Panel(child: _MonthlyChart(months: a.monthlyFuel)),
      const SizedBox(height: 20),
      const _SectionTitle('Consommation par matériel'),
      _Panel(
        child: Column(
          children: [
            for (final e in byFuel) _FuelRow(stats: e, total: a.totalLitres),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle('Prochaines maintenances'),
      for (final e in byMaintenance) _MaintenanceTile(stats: e, now: now),
      const SizedBox(height: 20),
      const _SectionTitle('Durée de vie estimée'),
      for (final e in byLife) _LifeTile(stats: e),
      const SizedBox(height: 8),
      const Text(
        'Estimations locales : durée de vie type de la catégorie ajustée '
        "selon l'état, l'intensité d'utilisation et le coût des réparations.",
        style: TextStyle(fontSize: 12),
      ),
    ];
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.analytics});

  final FleetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final tiles = [
      (
        'Carburant total',
        '${_num(a.totalLitres)} L',
        Icons.local_gas_station_outlined,
        const Color(0xFF1565C0),
      ),
      (
        'Coût carburant',
        '${_num(a.totalFuelCost, 2)} DT',
        Icons.payments_outlined,
        const Color(0xFF00838F),
      ),
      (
        'Moyenne / mois',
        '${_num(a.monthlyLitres)} L',
        Icons.speed_outlined,
        const Color(0xFF6A1B9A),
      ),
      (
        'Maintenances à prévoir',
        '${a.maintenancesDue}',
        Icons.build_circle_outlined,
        const Color(0xFFEF6C00),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value, icon, color) in tiles)
              SizedBox(
                width: width,
                child: _Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: inkGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.months});

  final List<MonthlyFuel> months;

  @override
  Widget build(BuildContext context) {
    final max = months.fold(0.0, (m, e) => e.litres > m ? e.litres : m);
    if (max == 0) {
      return const _Empty(
        icon: Icons.bar_chart_outlined,
        text: 'Aucun plein de carburant sur les 12 derniers mois.',
      );
    }
    const barArea = 130.0;
    final fuelColor = maintenanceTypeColor(MaintenanceRecordType.fuel);
    return SizedBox(
      height: barArea + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: Tooltip(
                message:
                    '${_months[m.month.month - 1]} ${m.month.year} : '
                    '${_num(m.litres)} L · ${_num(m.cost, 2)} DT',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (m.litres > 0)
                      FittedBox(
                        child: Text(
                          _num(m.litres, 0),
                          style: const TextStyle(
                            fontSize: 10,
                            color: inkGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Container(
                      height: m.litres == 0
                          ? 2
                          : (m.litres / max * barArea).clamp(4, barArea),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: m.litres == 0 ? borderGreen : fuelColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        _months[m.month.month - 1],
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FuelRow extends StatelessWidget {
  const _FuelRow({required this.stats, required this.total});

  final EquipmentStats stats;
  final double total;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final share = total > 0 ? s.fuelLitres / total : 0.0;
    final trend = s.trendPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.materiel.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trend != null) _TrendChip(percent: trend),
              const SizedBox(width: 8),
              Text(
                '${_num(s.fuelLitres)} L',
                style: const TextStyle(
                  color: inkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: borderGreen,
              color: maintenanceTypeColor(MaintenanceRecordType.fuel),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(share * 100).toStringAsFixed(0)} % du parc · '
            '${_num(s.monthlyLitres)} L/mois · ${_num(s.fuelCost, 2)} DT'
            '${s.pricePerLitre == null ? '' : ' · ${s.pricePerLitre!.toStringAsFixed(3)} DT/L'}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final up = percent > 0;
    // Higher fuel use is a warning, lower is good.
    final color = percent.abs() < 5
        ? mutedGreen
        : up
        ? const Color(0xFFC62828)
        : forestGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${up ? '+' : ''}${percent.toStringAsFixed(0)} %',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceTile extends StatelessWidget {
  const _MaintenanceTile({required this.stats, required this.now});

  final EquipmentStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final days = s.daysUntilMaintenance(now);
    final color = _urgencyColor(s.urgency);
    final when = days < 0
        ? 'en retard de ${-days} j'
        : days == 0
        ? "aujourd'hui"
        : 'dans $days j';
    return _Panel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(Icons.event_note_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.materiel.name,
                  style: const TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_date(s.nextMaintenance)} · $when',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Tous les ${s.maintenanceIntervalDays} j '
                  '(${s.intervalFromHistory ? 'historique' : 'valeur type'})'
                  '${s.lastMaintenance == null ? ' · aucune maintenance' : ' · dernière ${_date(s.lastMaintenance!)}'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.urgency.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeTile extends StatelessWidget {
  const _LifeTile({required this.stats});

  final EquipmentStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final used = s.lifeUsed;
    final color = used >= .9
        ? const Color(0xFFC62828)
        : used >= .65
        ? const Color(0xFFEF6C00)
        : forestGreen;
    return _Panel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.materiel.name,
                  style: const TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                s.remainingLifeYears <= 0
                    ? 'Fin de vie'
                    : '≈ ${_num(s.remainingLifeYears)} ans restants',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 8,
              backgroundColor: borderGreen,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_num(s.ageYears)} / ${_num(s.expectedLifeYears)} ans · '
            '${s.materiel.condition.label} · '
            'coût total ${_num(s.totalCost, 2)} DT',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.configured,
    required this.loading,
    required this.error,
    required this.report,
    required this.onRun,
  });

  final bool configured;
  final bool loading;
  final String? error;
  final AiFleetReport? report;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: forestGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Analyse IA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            configured
                ? "L'IA analyse vos consommations, planifie les maintenances "
                      'et estime la durée de vie de chaque matériel.'
                : 'Clé Gemini non configurée : ajoutez GEMINI_API_KEY '
                      'dans assets/config/env.json.',
            style: TextStyle(color: Colors.white.withValues(alpha: .85)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: forestGreen,
              ),
              onPressed: configured && !loading ? onRun : null,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_outlined),
              label: Text(
                loading
                    ? 'Analyse en cours…'
                    : r == null
                    ? "Analyser avec l'IA"
                    : "Relancer l'analyse",
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFFFCDD2),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (r != null) ...[
            const SizedBox(height: 14),
            _AiReportView(report: r),
          ],
        ],
      ),
    );
  }
}

class _AiReportView extends StatelessWidget {
  const _AiReportView({required this.report});

  final AiFleetReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.summary.isNotEmpty)
            Text(
              r.summary,
              style: const TextStyle(color: inkGreen, height: 1.4),
            ),
          if (r.consumption.isNotEmpty) ...[
            const _AiHeading(Icons.local_gas_station_outlined, 'Consommation'),
            for (final line in r.consumption) _Bullet(line),
          ],
          if (r.maintenances.isNotEmpty) ...[
            const _AiHeading(Icons.build_outlined, 'Maintenances prévues'),
            for (final m in r.maintenances)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _priorityColor(m.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '${m.equipment}'
                                  '${m.date == null ? '' : ' — ${_date(m.date!)}'}'
                                  ' (${m.priority})\n',
                              style: const TextStyle(
                                color: inkGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: m.reason),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (r.lifespans.isNotEmpty) ...[
            const _AiHeading(Icons.hourglass_bottom, 'Durée de vie'),
            for (final l in r.lifespans)
              _Bullet(
                '${l.equipment}'
                '${l.remainingYears == null ? '' : ' : ≈ ${_num(l.remainingYears!)} ans'}'
                '${l.comment.isEmpty ? '' : ' — ${l.comment}'}',
              ),
          ],
          if (r.recommendations.isNotEmpty) ...[
            const _AiHeading(Icons.lightbulb_outline, 'Recommandations'),
            for (final line in r.recommendations) _Bullet(line),
          ],
        ],
      ),
    );
  }
}

class _AiHeading extends StatelessWidget {
  const _AiHeading(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: forestGreen),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: forestGreen)),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: inkGreen,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderGreen),
    ),
    child: child,
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: mutedGreen, size: 40),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
