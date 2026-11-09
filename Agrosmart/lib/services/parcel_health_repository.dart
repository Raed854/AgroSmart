import '../models/drone.dart';
import '../models/parcel_health.dart';

/// Data source for the Parcel Health Map.
///
/// Implementation: [SqfliteParcelHealthRepository] (local database).
/// A FastAPI implementation only needs to call the matching endpoints, e.g.
/// `GET /parcels`, `GET /parcels/{id}/missions` and
/// `GET /missions/{id}/analysis`, and decode responses with the models'
/// `fromJson` factories.
abstract class ParcelHealthRepository {
  Future<List<Parcel>> fetchParcels();

  Future<List<DroneMission>> fetchMissions(String parcelId);

  Future<MissionAnalysis> fetchMissionAnalysis(String missionId);

  /// Inserts the parcel, or replaces it when its id already exists.
  Future<void> saveParcel(Parcel parcel);

  /// Deletes the parcel with its missions and analyses.
  Future<void> deleteParcel(String parcelId);

  /// Stores a new mission with its analysis (e.g. a disease API estimation).
  Future<void> saveMissionAnalysis(
    DroneMission mission,
    MissionAnalysis analysis,
  );

  /// Every drone of the farm, to choose the ones responsible for a parcel.
  Future<List<Drone>> fetchDrones();

  /// Ids of the drones responsible for the parcel.
  Future<Set<String>> fetchParcelDroneIds(String parcelId);

  /// Replaces the drones responsible for the parcel.
  Future<void> setParcelDrones(String parcelId, Set<String> droneIds);
}
