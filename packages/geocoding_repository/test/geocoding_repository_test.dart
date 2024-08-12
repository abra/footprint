import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geocoding_repository/geocoding_repository.dart';
import 'package:geocoding_repository/src/geocoding_cache_storage.dart';
import 'package:geocoding_repository/src/geocoding_service.dart';
import 'package:geocoding_repository/src/mappers/placemark_to_domain.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class MockSqliteStorage extends Mock implements SqliteStorage {}

class MockGeocodingCacheStorage extends Mock implements GeocodingCacheStorage {}

class MockGeocodingService extends Mock implements GeocodingService {}

void main() {
  late GeocodingRepository geocodingRepository;
  late MockSqliteStorage mockSqliteStorage;
  late MockGeocodingCacheStorage mockCacheStorage;
  late MockGeocodingService mockGeocodingService;

  setUp(() {
    mockSqliteStorage = MockSqliteStorage();
    mockCacheStorage = MockGeocodingCacheStorage();
    mockGeocodingService = MockGeocodingService();

    geocodingRepository = GeocodingRepository(
      sqliteStorage: mockSqliteStorage,
      cacheStorage: mockCacheStorage,
      geocodingService: mockGeocodingService,
    );
  });

  group('GeocodingRepository', () {
    test('getAddressFromCoordinates returns cached address when available',
        () async {
      final location = LocationModel(
        id: '1',
        latitude: 1.0,
        longitude: 1.0,
        timestamp: DateTime.now(),
      );
      final cachedAddress = 'Cached Address';

      when(() => mockCacheStorage.getAddressFromCache(location)).thenAnswer(
        (_) async => cachedAddress,
      );

      final result = await geocodingRepository.getAddressFromCoordinates(
        location,
      );

      expect(result.address, equals(cachedAddress));
      verify(() => mockCacheStorage.getAddressFromCache(location)).called(1);
      verifyNever(() => mockGeocodingService.getPlacemarkList(any(), any()));
    });

    test(
      'getAddressFromCoordinates uses GeocodingService when cache is empty',
      () async {
        final location = LocationModel(
          id: '1',
          latitude: 1.0,
          longitude: 1.0,
          timestamp: DateTime.now(),
        );

        final placemark = Placemark(street: 'Test Street');

        when(() => mockCacheStorage.getAddressFromCache(location)).thenAnswer(
          (_) async => null,
        );
        when(() => mockGeocodingService.getPlacemarkList(any(), any()))
            .thenAnswer(
          (_) async => [placemark],
        );
        when(
          () => mockCacheStorage.addAddressToCache(
              latitude: 1.0, longitude: 1.0, address: 'Test Street'),
        ).thenAnswer(
          (_) async => 1,
        );

        final result = await geocodingRepository.getAddressFromCoordinates(
          location,
        );

        expect(result.address, equals('Test Street'));
        verify(() => mockCacheStorage.getAddressFromCache(location)).called(1);
        verify(() => mockGeocodingService.getPlacemarkList(1.0, 1.0)).called(1);
        verify(
          () => mockCacheStorage.addAddressToCache(
            latitude: 1.0,
            longitude: 1.0,
            address: 'Test Street',
          ),
        ).called(1);
      },
    );

    test(
      'getAddressFromCoordinates throws exception on error',
      () async {
        final location = LocationModel(
          id: '1',
          latitude: 1.0,
          longitude: 1.0,
          timestamp: DateTime.now(),
        );

        when(() => mockCacheStorage.getAddressFromCache(location)).thenThrow(
          Exception('Test error'),
        );

        expect(
          () => geocodingRepository.getAddressFromCoordinates(
            location,
          ),
          throwsA(isA<CouldNotGetPlaceAddressException>()),
        );
      },
    );
  });

  group('PlacemarkToDomain', () {
    test('toDomainModel returns correct street address', () {
      final placemark = Placemark(
        street: '1 Main St',
        subLocality: 'Downtown',
        locality: 'City',
        administrativeArea: 'State',
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('1 Main St'));
    });

    test('toDomainModel handles partial no street address information', () {
      final placemark = Placemark(
        subThoroughfare: 'Avenue',
        thoroughfare: 'Main St',
        locality: 'City',
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('Avenue, Main St'));
    });

    test('toDomainModel handles no subThoroughfare address information', () {
      final placemark = Placemark(
        thoroughfare: 'Main St',
        locality: 'City',
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('Main St'));
    });

    test('toDomainModel handles no thoroughfare address information', () {
      final placemark = Placemark(
        subLocality: 'Downtown',
        locality: 'City',
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('Downtown, City'));
    });

    test('toDomainModel handles no subLocality address information', () {
      final placemark = Placemark(
        locality: 'City',
        administrativeArea: 'State',
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('City'));
    });

    test('toDomainModel handles no locality address information', () {
      final placemark = Placemark(
        subAdministrativeArea: 'State',
        administrativeArea: 'Adm',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('State, Adm'));
    });

    test('toDomainModel handles no subAdministrativeArea address information',
        () {
      final placemark = Placemark(
        administrativeArea: 'Adm',
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('Adm'));
    });

    test('toDomainModel handles no administrativeArea address information', () {
      final placemark = Placemark(
        country: 'Country',
      );

      final result = placemark.toDomainModel();

      expect(result.address, equals('Country'));
    });

    test('toDomainModel returns null address when no information available',
        () {
      final placemark = Placemark();

      final result = placemark.toDomainModel();

      expect(result.address, isNull);
    });
  });
}
