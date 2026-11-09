import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/irrigation_plan.dart';
import '../models/irrigation_record.dart';
import '../models/parcel_health.dart';
import '../services/irrigation_plan_repository.dart';
import '../services/irrigation_planner_service.dart';
import '../services/irrigation_repository.dart';
import '../services/parcel_health_repository.dart';
import '../services/sqflite_parcel_health_repository.dart';
import '../services/weather_service.dart';
import '../utils/geo_utils.dart';
import '../widgets/irrigation_charts.dart';

const _waterBlue = Color(0xFF0277BD);
const _skipGrey = Color(0xFFB7C2BA);
const _checkAmber = Color(0xFFE08A00);
const _humidityGreen = Color(0xFF2E7D32);
const _et0Orange = Color(0xFFD84315);

Color _actionColor(PlanAction action) => switch (action) {
  PlanAction.irrigate => _waterBlue,
  PlanAction.skip => _skipGrey,
  PlanAction.check => _checkAmber,
};

IconData _actionIcon(PlanAction action) => switch (action) {
  PlanAction.irrigate => Icons.water_drop,
  PlanAction.skip => Icons.block,
  PlanAction.check => Icons.sensors,
};

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _shortDay(DateTime d) => frenchDayName(d).substring(0, 3);

String _dateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'
    ' à ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// "Planning irrigation IA": the farmer picks a parcel and the AI builds a
/// day-by-day irrigation planning for it.
class IrrigationPlanningScreen extends StatefulWidget {
  const IrrigationPlanningScreen({
    super.key,
    this.parcelRepository,
    this.irrigationRepository,
    this.planRepository,
    this.planner,
    this.weather,
  });

  final ParcelHealthRepository? parcelRepository;
  final IrrigationRepository? irrigationRepository;
  final IrrigationPlanRepository? planRepository;
  final IrrigationPlannerService? planner;
  final WeatherService? weather;

  @override
  State<IrrigationPlanningScreen> createState() =>
      _IrrigationPlanningScreenState();
}

class _IrrigationPlanningScreenState extends State<IrrigationPlanningScreen> {
  late final ParcelHealthRepository _parcels =
      widget.parcelRepository ?? SqfliteParcelHealthRepository();
  late final IrrigationRepository _records =
      widget.irrigationRepository ?? SqfliteIrrigationRepository();
  late final IrrigationPlanRepository _plans =
      widget.planRepository ?? SqfliteIrrigationPlanRepository();
  late final IrrigationPlannerService _planner =
      widget.planner ?? IrrigationPlannerService();
  late final WeatherService _weather = widget.weather ?? WeatherService();

  List<Parcel>? _items;
  Map<String, IrrigationPlan?> _savedPlans = const {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final parcels = await _parcels.fetchParcels();
      final plans = await Future.wait(
        parcels.map((p) => _plans.fetchPlan(p.id)),
      );
      if (!mounted) return;
      setState(() {
        _items = parcels;
        _savedPlans = {
          for (var i = 0; i < parcels.length; i++) parcels[i].id: plans[i],
        };
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _open(Parcel parcel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelIrrigationPlanScreen(
          parcel: parcel,
          irrigationRepository: _records,
          planRepository: _plans,
          planner: _planner,
          weather: _weather,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Planning irrigation IA',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: forestGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: .16),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Sélectionnez une parcelle : l'IA génère un planning "
                        "d'irrigation selon la météo et l'humidité du sol.",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Parcelles',
                      style: TextStyle(
                        color: inkGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (items != null)
                    Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: mutedGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadFailed)
                const _EmptyState(
                  icon: Icons.error_outline,
                  text: 'Impossible de charger les parcelles.',
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const _EmptyState(
                  icon: Icons.crop_square_outlined,
                  text:
                      'Aucune parcelle. Créez-en une depuis la carte '
                      'Parcel Health Map.',
                )
              else
                ...items.map(
                  (parcel) => _ParcelPlanCard(
                    parcel: parcel,
                    plan: _savedPlans[parcel.id],
                    onTap: () => _open(parcel),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParcelPlanCard extends StatelessWidget {
  const _ParcelPlanCard({
    required this.parcel,
    required this.plan,
    required this.onTap,
  });

  final Parcel parcel;
  final IrrigationPlan? plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final status = plan == null
        ? 'Aucun planning — touchez pour générer'
        : plan.isOutdated(DateTime.now())
        ? 'Planning à mettre à jour'
        : '${plan.irrigationDays} irrigation${plan.irrigationDays > 1 ? 's' : ''}'
              ' prévue${plan.irrigationDays > 1 ? 's' : ''} · '
              '${formatLiters(plan.totalLiters)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderGreen),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE1F2FB),
          child: Icon(Icons.calendar_month_outlined, color: _waterBlue),
        ),
        title: Text(
          parcel.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${parcel.cropType} · ${_num(parcel.surfaceHectares)} ha\n$status',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

/// The AI planning of one parcel. It is recomputed automatically when the
/// weather forecast or the soil moisture changes.
class ParcelIrrigationPlanScreen extends StatefulWidget {
  const ParcelIrrigationPlanScreen({
    super.key,
    required this.parcel,
    required this.irrigationRepository,
    required this.planRepository,
    required this.planner,
    required this.weather,
    this.recheckEvery = const Duration(minutes: 30),
  });

  final Parcel parcel;
  final IrrigationRepository irrigationRepository;
  final IrrigationPlanRepository planRepository;
  final IrrigationPlannerService planner;
  final WeatherService weather;

  /// How often the forecast is re-checked while the page is open.
  final Duration recheckEvery;

  @override
  State<ParcelIrrigationPlanScreen> createState() =>
      _ParcelIrrigationPlanScreenState();
}

class _ParcelIrrigationPlanScreenState
    extends State<ParcelIrrigationPlanScreen> {
  IrrigationPlan? _plan;
  List<IrrigationRecord> _history = const [];
  List<WeatherDay>? _forecast;
  String? _weatherError;

  /// Soil moisture measured by the farmer (%), `null` when unknown.
  double? _humidity;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  /// Why the planning was just recomputed.
  String? _notice;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
    _timer = Timer.periodic(widget.recheckEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        widget.planRepository.fetchPlan(widget.parcel.id),
        widget.irrigationRepository.fetchRecords(widget.parcel.id),
      ]);
      if (!mounted) return;
      final plan = results[0] as IrrigationPlan?;
      final history = results[1] as List<IrrigationRecord>;
      final latest = history.isEmpty ? null : history.first;
      setState(() {
        _plan = plan;
        _history = history;
        _humidity =
            plan?.soilHumidity ??
            latest?.humidityAfter ??
            latest?.humidityBefore;
      });
    } catch (_) {
      // No cache / history: the AI still works from the weather alone.
    }
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  /// Fetches the forecast and regenerates the planning if its inputs changed.
  Future<void> _refresh({bool force = false}) async {
    List<WeatherDay>? forecast;
    String? weatherError;
    final boundary = widget.parcel.boundary;
    if (boundary.isEmpty) {
      weatherError = 'Parcelle sans contour : météo indisponible.';
    } else {
      try {
        forecast = await widget.weather.forecast(polygonCentroid(boundary));
      } on WeatherException catch (e) {
        weatherError = e.message;
      }
    }
    if (!mounted) return;
    setState(() {
      _forecast = forecast ?? _forecast;
      _weatherError = weatherError;
    });

    final plan = _plan;
    final weatherSig = weatherSignature(_forecast);
    final humiditySig = humiditySignature(
      _humidity,
      _history.isEmpty ? null : _history.first.id,
    );
    final String? reason;
    if (force) {
      reason = 'Planning recalculé à votre demande.';
    } else if (plan == null) {
      reason = 'Premier planning généré pour cette parcelle.';
    } else if (plan.isOutdated(DateTime.now())) {
      reason = 'Nouvelle semaine : planning mis à jour.';
    } else if (forecast != null && plan.weatherSignature != weatherSig) {
      reason = 'Les prévisions météo ont changé : planning recalculé.';
    } else if (plan.humiditySignature != humiditySig) {
      reason = "L'humidité du sol a changé : planning recalculé.";
    } else {
      reason = null;
    }
    if (reason != null) {
      await _generate(reason, weatherSig: weatherSig, humiditySig: humiditySig);
    }
  }

  Future<void> _generate(
    String reason, {
    required String weatherSig,
    required String humiditySig,
  }) async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final plan = await widget.planner.generate(
        parcel: widget.parcel,
        history: _history,
        weather: _forecast ?? const [],
        soilHumidity: _humidity,
        weatherSignature: weatherSig,
        humiditySignature: humiditySig,
      );
      await widget.planRepository.savePlan(plan);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _notice = reason;
      });
    } on IrrigationPlannerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Échec de la génération du planning.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _setHumidity(double? value) {
    setState(() => _humidity = value);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: Text(
          parcel.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Régénérer le planning',
            onPressed: _generating ? null : () => _refresh(force: true),
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _Header(parcel: parcel, plan: plan),
              const SizedBox(height: 14),
              _HumidityCard(
                value: _humidity,
                enabled: !_generating,
                onChanged: _setHumidity,
              ),
              if (_generating) ...[
                const SizedBox(height: 14),
                const _Banner(
                  icon: Icons.auto_awesome,
                  color: _waterBlue,
                  text: "L'IA calcule le planning…",
                  loading: true,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _Banner(
                  icon: Icons.error_outline,
                  color: const Color(0xFFC62828),
                  text: _error!,
                ),
              ],
              if (_weatherError != null) ...[
                const SizedBox(height: 14),
                _Banner(
                  icon: Icons.cloud_off_outlined,
                  color: _checkAmber,
                  text: _forecast == null
                      ? '$_weatherError Planning basé sur l\'historique.'
                      : '$_weatherError Dernières prévisions conservées.',
                ),
              ],
              if (_notice != null && !_generating) ...[
                const SizedBox(height: 14),
                _Banner(icon: Icons.sync, color: forestGreen, text: _notice!),
              ],
              const SizedBox(height: 18),
              if (plan == null)
                _loading || _generating
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const _EmptyState(
                        icon: Icons.calendar_month_outlined,
                        text: 'Aucun planning pour le moment.',
                      )
              else ...[
                if (plan.summary.isNotEmpty) ...[
                  _Section(
                    title: 'Stratégie de la semaine',
                    child: Text(plan.summary),
                  ),
                  const SizedBox(height: 14),
                ],
                _Section(
                  title: 'Planning',
                  child: _PlanTable(days: plan.days),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: "Quantité d'eau par jour",
                  child: DayChart(
                    labels: [for (final d in plan.days) _shortDay(d.date)],
                    unit: 'L',
                    format: formatLiters,
                    series: [
                      ChartSeries(
                        label: 'Eau',
                        asBars: true,
                        color: _waterBlue,
                        values: [for (final d in plan.days) d.liters ?? 0],
                        barColors: [
                          for (final d in plan.days) _actionColor(d.action),
                        ],
                      ),
                    ],
                  ),
                ),
                if (plan.days.any((d) => d.expectedHumidity != null)) ...[
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Humidité du sol prévue',
                    child: DayChart(
                      labels: [for (final d in plan.days) _shortDay(d.date)],
                      unit: '%',
                      fixedMax: 100,
                      series: [
                        ChartSeries(
                          label: 'Humidité',
                          color: _humidityGreen,
                          values: [
                            for (final d in plan.days) d.expectedHumidity,
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (plan.weather.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Prévisions météo utilisées',
                    child: DayChart(
                      labels: [for (final w in plan.weather) _shortDay(w.date)],
                      unit: 'mm',
                      series: [
                        ChartSeries(
                          label: 'Pluie',
                          asBars: true,
                          color: _waterBlue,
                          values: [for (final w in plan.weather) w.rainMm],
                        ),
                        ChartSeries(
                          label: 'Évapotranspiration (ET0)',
                          color: _et0Orange,
                          values: [for (final w in plan.weather) w.et0Mm],
                        ),
                      ],
                    ),
                  ),
                ],
                if (plan.advice.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Conseils',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tip in plan.advice)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: forestGreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tip)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Généré le ${_dateTime(plan.generatedAt)} · recalcul '
                  'automatique si la météo ou l\'humidité change.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.parcel, required this.plan});

  final Parcel parcel;
  final IrrigationPlan? plan;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: forestGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${parcel.cropType} · ${_num(parcel.surfaceHectares)} ha',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'Eau prévue',
                value: plan == null ? '—' : formatLiters(plan.totalLiters),
              ),
              _Stat(
                label: 'Irrigations',
                value: plan == null ? '—' : '${plan.irrigationDays}',
              ),
              _Stat(
                label: 'Pluie prévue',
                value: plan == null || plan.weather.isEmpty
                    ? '—'
                    : '${_num(plan.weather.fold(0.0, (s, w) => s + w.rainMm))} mm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

class _HumidityCard extends StatelessWidget {
  const _HumidityCard({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return _Section(
      title: 'Humidité du sol mesurée',
      trailing: value == null
          ? null
          : Text(
              '${_num(value)} %',
              style: const TextStyle(
                color: inkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
      child: value == null
          ? Row(
              children: [
                const Expanded(
                  child: Text(
                    "Aucune mesure : l'IA s'appuie sur la météo et "
                    "l'historique.",
                  ),
                ),
                TextButton(
                  onPressed: enabled ? () => onChanged(40) : null,
                  child: const Text('Saisir'),
                ),
              ],
            )
          : Column(
              children: [
                _HumiditySlider(
                  value: value,
                  enabled: enabled,
                  onChangeEnd: onChanged,
                ),
                const Text(
                  'Relâchez le curseur : le planning est recalculé.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

/// Moves freely while dragging; only the released value triggers the AI.
class _HumiditySlider extends StatefulWidget {
  const _HumiditySlider({
    required this.value,
    required this.enabled,
    required this.onChangeEnd,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_HumiditySlider> createState() => _HumiditySliderState();
}

class _HumiditySliderState extends State<_HumiditySlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(_HumiditySlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Slider(
    value: _value.clamp(0, 100),
    max: 100,
    divisions: 50,
    label: '${_value.round()} %',
    activeColor: _humidityGreen,
    onChanged: widget.enabled ? (v) => setState(() => _value = v) : null,
    onChangeEnd: widget.enabled ? widget.onChangeEnd : null,
  );
}

class _PlanTable extends StatelessWidget {
  const _PlanTable({required this.days});

  final List<IrrigationPlanDay> days;

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(
      color: mutedGreen,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 82, child: Text('Jour', style: header)),
              Expanded(child: Text('Recommandation', style: header)),
              SizedBox(
                width: 76,
                child: Text(
                  'Quantité',
                  style: header,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        for (final day in days) _PlanRow(day: day),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.day});

  final IrrigationPlanDay day;

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(day.action);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: borderGreen)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          expandedAlignment: Alignment.centerLeft,
          dense: true,
          showTrailingIcon: false,
          title: Row(
            children: [
              SizedBox(
                width: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.dayName,
                      style: const TextStyle(
                        color: inkGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${day.date.day.toString().padLeft(2, '0')}/'
                      '${day.date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(_actionIcon(day.action), size: 16, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        day.action.label,
                        style: const TextStyle(
                          color: inkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  formatLiters(day.liters),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          children: [
            if (day.reason.isNotEmpty) Text(day.reason),
            if (day.expectedHumidity != null)
              Text(
                'Humidité prévue : ${_num(day.expectedHumidity!)} %',
                style: const TextStyle(fontSize: 12.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    // A Material (not a decorated Container) so the planning rows' ink
    // splashes stay visible.
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: borderGreen),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: inkGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.loading = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: inkGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

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
