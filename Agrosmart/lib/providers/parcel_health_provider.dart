import 'package:flutter/foundation.dart';

import '../models/drone.dart';
import '../models/parcel_health.dart';
import '../services/disease_api_service.dart';
import '../services/parcel_health_repository.dart';

class ParcelHealthProvider extends ChangeNotifier {
  ParcelHealthProvider(this._repository, {DiseaseApiService? diseaseApi})
    : _diseaseApi = diseaseApi ?? DiseaseApiService();

  final ParcelHealthRepository _repository;
  final DiseaseApiService _diseaseApi;

  bool isAnalysing = false;

  List<Parcel> parcels = [];
  List<DroneMission> missions = [];
  MissionAnalysis? analysis;

  /// Every drone of the farm.
  List<Drone> drones = [];

  /// Ids of the drones responsible for [selectedParcel].
  Set<String> parcelDroneIds = {};

  List<Drone> get parcelDrones =>
      drones.where((d) => parcelDroneIds.contains(d.id)).toList();

  Parcel? selectedParcel;
  DroneMission? selectedMission;
  Anomaly? selectedAnomaly;

  /// `null` means "All".
  AnomalyType? typeFilter;
  Severity? severityFilter;

  bool isLoading = false;
  String? error;

  // Guards against out-of-order responses when the farmer switches quickly.
  int _requestId = 0;

  List<Anomaly> get filteredAnomalies => (analysis?.anomalies ?? [])
      .where((a) => typeFilter == null || a.type == typeFilter)
      .where((a) => severityFilter == null || a.severity == severityFilter)
      .toList();

  Future<void> load() => _reload();

  /// Stores a new or edited parcel and shows it on the map.
  Future<void> saveParcel(Parcel parcel) async {
    await _repository.saveParcel(parcel);
    await _reload(selectId: parcel.id);
  }

  /// Replaces the drones responsible for the selected parcel.
  Future<void> setParcelDrones(Set<String> droneIds) async {
    final parcel = selectedParcel;
    if (parcel == null) return;
    await _repository.setParcelDrones(parcel.id, droneIds);
    parcelDroneIds = Set.of(droneIds);
    notifyListeners();
  }

  /// Reloads the drone list, e.g. after a drone was created.
  Future<void> reloadDrones() async {
    drones = await _repository.fetchDrones();
    final parcel = selectedParcel;
    if (parcel != null) {
      parcelDroneIds = await _repository.fetchParcelDroneIds(parcel.id);
    }
    notifyListeners();
  }

  Future<void> deleteParcel(String parcelId) async {
    await _repository.deleteParcel(parcelId);
    await _reload();
  }

  /// Sends the selected parcel's surface to the disease API, stores the
  /// estimation as a new mission and shows its zones on the map.
  ///
  /// Throws [DiseaseApiException] when the API fails.
  Future<void> analyseDiseases({double? temperature, double? humidity}) async {
    final parcel = selectedParcel;
    if (parcel == null || isAnalysing) return;
    isAnalysing = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final mission = DroneMission(
        id: 'estimation-${now.millisecondsSinceEpoch}',
        parcelId: parcel.id,
        label: 'Disease estimation',
        flownAt: now,
      );
      final result = await _diseaseApi.analyse(
        parcel,
        missionId: mission.id,
        temperature: temperature,
        humidity: humidity,
      );
      await _repository.saveMissionAnalysis(mission, result);
      await _run(() async {
        missions = await _repository.fetchMissions(parcel.id);
        await _loadMission(
          missions.firstWhere((m) => m.id == mission.id, orElse: () => mission),
        );
      });
    } finally {
      isAnalysing = false;
      notifyListeners();
    }
  }

  Future<void> _reload({String? selectId}) async {
    await _run(() async {
      parcels = await _repository.fetchParcels();
      drones = await _repository.fetchDrones();
      final id = selectId ?? selectedParcel?.id;
      final parcel =
          parcels.where((p) => p.id == id).firstOrNull ?? parcels.firstOrNull;
      if (parcel == null) {
        selectedParcel = null;
        selectedMission = null;
        selectedAnomaly = null;
        parcelDroneIds = {};
        missions = [];
        analysis = null;
      } else {
        await _loadParcel(parcel);
      }
    });
  }

  Future<void> selectParcel(Parcel parcel) async {
    if (parcel.id == selectedParcel?.id) return;
    await _run(() => _loadParcel(parcel));
  }

  Future<void> selectMission(DroneMission mission) async {
    if (mission.id == selectedMission?.id) return;
    await _run(() => _loadMission(mission));
  }

  void setTypeFilter(AnomalyType? type) {
    typeFilter = type;
    _clearHiddenSelection();
    notifyListeners();
  }

  void setSeverityFilter(Severity? severity) {
    severityFilter = severity;
    _clearHiddenSelection();
    notifyListeners();
  }

  void selectAnomaly(Anomaly? anomaly) {
    selectedAnomaly = anomaly;
    notifyListeners();
  }

  Future<void> _loadParcel(Parcel parcel) async {
    if (parcel.id != selectedParcel?.id) {
      // Don't draw the previous parcel's zones while the new one loads.
      analysis = null;
      selectedAnomaly = null;
    }
    selectedParcel = parcel;
    parcelDroneIds = await _repository.fetchParcelDroneIds(parcel.id);
    missions = await _repository.fetchMissions(parcel.id);
    if (missions.isEmpty) {
      selectedMission = null;
      selectedAnomaly = null;
      analysis = null;
      return;
    }
    await _loadMission(missions.first);
  }

  Future<void> _loadMission(DroneMission mission) async {
    selectedMission = mission;
    selectedAnomaly = null;
    analysis = await _repository.fetchMissionAnalysis(mission.id);
  }

  void _clearHiddenSelection() {
    if (selectedAnomaly != null &&
        !filteredAnomalies.contains(selectedAnomaly)) {
      selectedAnomaly = null;
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    final requestId = ++_requestId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await task();
    } catch (e) {
      if (requestId == _requestId) error = 'Unable to load parcel data.';
    } finally {
      if (requestId == _requestId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }
}
