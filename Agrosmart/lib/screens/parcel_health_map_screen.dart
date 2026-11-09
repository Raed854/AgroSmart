import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/parcel_health.dart';
import '../providers/parcel_health_provider.dart';
import '../services/disease_api_service.dart';
import '../services/parcel_health_repository.dart';
import '../services/sqflite_parcel_health_repository.dart';
import '../utils/geo_utils.dart';
import '../widgets/parcel_health/anomaly_details_sheet.dart';
import '../widgets/parcel_health/health_palette.dart';
import '../widgets/parcel_health/health_statistics.dart';
import '../widgets/parcel_health/map_filter_panel.dart';
import '../widgets/parcel_health/parcel_drones_card.dart';
import '../widgets/parcel_health/parcel_health_map.dart';
import '../widgets/parcel_health/parcel_info_card.dart';
import '../widgets/map_aware_scroll_view.dart';
import 'anomaly_detail_screen.dart';
import 'drone_form_screen.dart';
import 'parcel_editor_screen.dart';
import 'statistic_detail_screen.dart';

class ParcelHealthMapScreen extends StatelessWidget {
  const ParcelHealthMapScreen({super.key, this.repository, this.diseaseApi});

  /// Defaults to the local sqflite database; inject a FastAPI repository
  /// later.
  final ParcelHealthRepository? repository;

  /// Defaults to the Flask API at [diseaseApiUrl].
  final DiseaseApiService? diseaseApi;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ParcelHealthProvider(
        repository ?? SqfliteParcelHealthRepository(),
        diseaseApi: diseaseApi,
      )..load(),
      child: const _ParcelHealthMapView(),
    );
  }
}

class _ParcelHealthMapView extends StatefulWidget {
  const _ParcelHealthMapView();

  @override
  State<_ParcelHealthMapView> createState() => _ParcelHealthMapViewState();
}

class _ParcelHealthMapViewState extends State<_ParcelHealthMapView> {
  // Page scrolling is paused while a finger is on the map so it can pan.
  final _mapActive = ValueNotifier(false);

  @override
  void dispose() {
    _mapActive.dispose();
    super.dispose();
  }

  void _openAnomaly(Anomaly anomaly) {
    final provider = context.read<ParcelHealthProvider>();
    provider.selectAnomaly(anomaly);
    AnomalyDetailsSheet.show(
      context,
      anomaly: anomaly,
      onViewDetails: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnomalyDetailScreen(
              anomaly: anomaly,
              parcelName: provider.selectedParcel?.name ?? '',
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor({Parcel? parcel}) async {
    final provider = context.read<ParcelHealthProvider>();
    final current = provider.selectedParcel;
    var created = false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelEditorScreen(
          parcel: parcel,
          initialCenter: current == null
              ? defaultMapCenter
              : polygonCentroid(current.boundary),
          onSave: (saved) async {
            await provider.saveParcel(saved);
            created = parcel == null;
          },
          onDelete: (parcel) => provider.deleteParcel(parcel.id),
        ),
      ),
    );
    // A new parcel needs at least one responsible drone.
    if (created && mounted && provider.drones.isNotEmpty) {
      await _selectDrones();
    }
  }

  Future<void> _selectDrones() async {
    final provider = context.read<ParcelHealthProvider>();
    final parcel = provider.selectedParcel;
    if (parcel == null) return;
    final ids = await showParcelDronePicker(
      context,
      parcelName: parcel.name,
      drones: provider.drones,
      selected: provider.parcelDroneIds,
    );
    if (ids == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.setParcelDrones(ids);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Impossible d'enregistrer les drones."),
          backgroundColor: criticalColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createDrone() async {
    final provider = context.read<ParcelHealthProvider>();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DroneFormScreen()),
    );
    if (created != true || !mounted) return;
    await provider.reloadDrones();
    if (mounted) await _selectDrones();
  }

  Future<void> _analyseDiseases() async {
    final weather = await showDialog<({double? temperature, double? humidity})>(
      context: context,
      builder: (_) => const _WeatherDialog(),
    );
    if (weather == null || !mounted) return;
    final provider = context.read<ParcelHealthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.analyseDiseases(
        temperature: weather.temperature,
        humidity: weather.humidity,
      );
      final count = provider.analysis?.anomalies.length ?? 0;
      messenger.showSnackBar(
        SnackBar(
          content: Text('$count disease(s) estimated and shown on the map.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is DiseaseApiException ? e.message : 'Disease analysis failed.',
          ),
          backgroundColor: criticalColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParcelHealthProvider>();
    final parcel = provider.selectedParcel;
    final analysis = provider.analysis;
    final anomalies = provider.filteredAnomalies;

    return Scaffold(
      backgroundColor: healthBackground,
      body: SafeArea(
        child: MapAwareScrollView(
          locked: _mapActive,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _Header(),
            const SizedBox(height: 20),
            if (parcel == null && !provider.isLoading && provider.error == null)
              _NoParcels(onAdd: () => _openEditor())
            else if (parcel == null)
              _LoadingOrError(error: provider.error, onRetry: provider.load)
            else ...[
              ParcelInfoCard(
                parcel: parcel,
                mission: provider.selectedMission,
                overallHealth: analysis?.overallHealth,
                onEdit: () => _openEditor(parcel: parcel),
              ),
              const SizedBox(height: 12),
              ParcelDronesCard(
                drones: provider.parcelDrones,
                hasAnyDrone: provider.drones.isNotEmpty,
                onSelect: _selectDrones,
                onCreateDrone: _createDrone,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: provider.isAnalysing || provider.isLoading
                      ? null
                      : _analyseDiseases,
                  style: FilledButton.styleFrom(
                    backgroundColor: healthPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: provider.isAnalysing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.coronavirus_outlined),
                  label: Text(
                    provider.isAnalysing
                        ? 'Analysing ${parcel.surfaceHectares} ha…'
                        : 'Analyse diseases on this surface',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              MapFilterPanel(
                parcels: provider.parcels,
                missions: provider.missions,
                selectedParcel: parcel,
                selectedMission: provider.selectedMission,
                typeFilter: provider.typeFilter,
                severityFilter: provider.severityFilter,
                enabled: !provider.isLoading,
                onAddParcel: () => _openEditor(),
                onParcelChanged: provider.selectParcel,
                onMissionChanged: provider.selectMission,
                onTypeChanged: provider.setTypeFilter,
                onSeverityChanged: provider.setSeverityFilter,
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                title: 'Field health map',
                trailing: '${anomalies.length} markers',
              ),
              const SizedBox(height: 10),
              ParcelHealthMap(
                parcel: parcel,
                zones: analysis?.zones ?? const [],
                anomalies: anomalies,
                selectedAnomaly: provider.selectedAnomaly,
                isLoading: provider.isLoading,
                onAnomalyTap: _openAnomaly,
                onMapTap: () => provider.selectAnomaly(null),
                onInteractionChanged: (active) => _mapActive.value = active,
              ),
              if (provider.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  provider.error!,
                  style: const TextStyle(color: criticalColor),
                ),
              ],
              const SizedBox(height: 20),
              const _SectionTitle(title: 'Health statistics'),
              const SizedBox(height: 10),
              if (analysis == null && !provider.isLoading)
                const _NoMissionYet()
              else if (analysis != null)
                HealthStatistics(
                  healthyPercent: analysis.healthyPercent,
                  warningPercent: analysis.warningPercent,
                  criticalPercent: analysis.criticalPercent,
                  totalAnomalies: analysis.anomalies.length,
                  visibleAnomalies: anomalies.length,
                  onZoneTap: (status) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatisticDetailScreen.zones(
                        status: status,
                        analysis: analysis,
                        parcelName: parcel.name,
                      ),
                    ),
                  ),
                  onAnomaliesTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatisticDetailScreen.anomalies(
                        analysis: analysis,
                        parcelName: parcel.name,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Row(
      children: [
        if (canPop) ...[
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
        ],
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parcel Health Map',
                style: TextStyle(
                  color: healthInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Monitor your agricultural fields',
                style: TextStyle(color: healthMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        Badge(
          smallSize: 9,
          backgroundColor: criticalColor,
          child: _RoundIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('3 new AI alerts for your parcels'),
                behavior: SnackBarBehavior.floating,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const CircleAvatar(
          radius: 21,
          backgroundColor: healthSecondary,
          child: Text(
            'AG',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: healthBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: healthInk, size: 22),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: healthInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(
            color: healthPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 80),
    child: Center(
      child: error == null
          ? const CircularProgressIndicator(color: healthPrimary)
          : Column(
              children: [
                Text(error!, style: const TextStyle(color: healthMuted)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
    ),
  );
}

class _NoParcels extends StatelessWidget {
  const _NoParcels({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: healthCardDecoration(),
    child: Column(
      children: [
        const Icon(Icons.map_outlined, size: 48, color: healthSecondary),
        const SizedBox(height: 12),
        const Text(
          'No parcel yet',
          style: TextStyle(
            color: healthInk,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create your first parcel by setting its 4 corners.',
          textAlign: TextAlign.center,
          style: TextStyle(color: healthMuted),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(backgroundColor: healthPrimary),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('New parcel'),
        ),
      ],
    ),
  );
}

/// Optional weather the disease API uses to refine its estimation.
class _WeatherDialog extends StatefulWidget {
  const _WeatherDialog();

  @override
  State<_WeatherDialog> createState() => _WeatherDialogState();
}

class _WeatherDialogState extends State<_WeatherDialog> {
  final _temperature = TextEditingController();
  final _humidity = TextEditingController();

  @override
  void dispose() {
    _temperature.dispose();
    _humidity.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label, String suffix) => InputDecoration(
      labelText: label,
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
    const keyboard = TextInputType.numberWithOptions(decimal: true);

    return AlertDialog(
      title: const Text('Analyse diseases'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The selected surface is sent to the disease API. Weather is '
            'optional but makes the estimation more reliable.',
            style: TextStyle(color: healthMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _temperature,
            keyboardType: keyboard,
            decoration: decoration('Temperature (optional)', '°C'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _humidity,
            keyboardType: keyboard,
            decoration: decoration('Humidity (optional)', '%'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: healthPrimary),
          onPressed: () => Navigator.pop(context, (
            temperature: _parse(_temperature),
            humidity: _parse(_humidity),
          )),
          child: const Text('Analyse'),
        ),
      ],
    );
  }
}

class _NoMissionYet extends StatelessWidget {
  const _NoMissionYet();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: healthCardDecoration(),
    child: const Row(
      children: [
        Icon(Icons.flight_takeoff_rounded, color: healthSecondary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'No drone mission analysed for this parcel yet. Statistics '
            'will appear after the first AI analysis.',
            style: TextStyle(color: healthMuted, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
