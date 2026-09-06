import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding_manager/geocoding_manager.dart';

export '../../../recording_service/test/fakes.dart';

class FakeGeocodingManager extends Fake implements GeocodingManager {
  Future<PlaceAddressDM?> Function(LocationDM)? lookup;
  @override
  Future<PlaceAddressDM?> getAddressFromCoordinates(
    LocationDM location,
  ) async => lookup == null ? null : lookup!(location);
  @override
  Future<void> dispose() async {}
}
