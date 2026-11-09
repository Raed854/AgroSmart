import 'package:my_application/models/drone.dart';
import 'package:my_application/models/parcel_health.dart';
import 'package:my_application/services/parcel_health_repository.dart';

import 'mock_parcel_health_data.dart';

/// In-memory repository filled with the demo fixtures, for tests only.
class MockParcelHealthRepository implements ParcelHealthRepository {
  static const _latency = Duration(milliseconds: 450);

  final _parcels = List.of(mockParcels);
  final _missions = List.of(mockMissions);
  final _analyses = Map.of(mockAnalyses);
  final _parcelDrones = <String, Set<String>>{};

  /// Drones available for assignment; tests can fill it.
  final drones = <Drone>[];

  @override
  Future<List<Parcel>> fetchParcels() async {
    await Future<void>.delayed(_latency);
    return List.of(_parcels);
  }

  @override
  Future<List<DroneMission>> fetchMissions(String parcelId) async {
    await Future<void>.delayed(_latency);
    return _missions.where((mission) => mission.parcelId == parcelId).toList()
      ..sort((a, b) => b.flownAt.compareTo(a.flownAt));
  }

  @override
  Future<MissionAnalysis> fetchMissionAnalysis(String missionId) async {
    await Future<void>.delayed(_latency);
    return _analyses[missionId]!;
  }

  @override
  Future<void> saveParcel(Parcel parcel) async {
    final index = _parcels.indexWhere((p) => p.id == parcel.id);
    if (index == -1) {
      _parcels.add(parcel);
    } else {
      _parcels[index] = parcel;
    }
  }

  @override
  Future<void> deleteParcel(String parcelId) async {
    _parcels.removeWhere((p) => p.id == parcelId);
    _parcelDrones.remove(parcelId);
  }

  @override
  Future<void> saveMissionAnalysis(
    DroneMission mission,
    MissionAnalysis analysis,
  ) async {
    _missions.add(mission);
    _analyses[mission.id] = analysis;
  }

  @override
  Future<List<Drone>> fetchDrones() async => List.of(drones);

  @override
  Future<Set<String>> fetchParcelDroneIds(String parcelId) async =>
      Set.of(_parcelDrones[parcelId] ?? const {});

  @override
  Future<void> setParcelDrones(String parcelId, Set<String> droneIds) async {
    _parcelDrones[parcelId] = Set.of(droneIds);
  }
}
