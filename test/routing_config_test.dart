import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/config/application_config.dart';
import 'package:footprint/app/composition.dart';
import 'package:route_planning/route_planning.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../packages/features/map/test/fakes.dart';

class RoutingTestConfig extends ApplicationConfig {
  const RoutingTestConfig({this.url = OpenRouteServicePlanner.defaultEndpoint});
  final String url;
  @override
  Uri get routingEndpoint => Uri.parse(url);
  @override
  String get routingApiKey => 'heigit-test-key';
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('existing configuration defaults remain valid', () {
    const config = ApplicationConfig();
    config.validate();
    expect(config.routingEndpoint.host, 'api.heigit.org');
    expect(
      config.routingEndpoint.toString(),
      OpenRouteServicePlanner.defaultEndpoint,
    );
  });

  test('routing requires HTTPS and no credentials embedded in URLs', () {
    for (final url in [
      'http://routing.example/route',
      'https:///route',
      'https://user:password@routing.example/route',
    ]) {
      expect(
        () => RoutingTestConfig(url: url).validate(),
        throwsFormatException,
      );
    }
    const RoutingTestConfig().validate();
    const RoutingTestConfig(url: 'https://routing.example/route').validate();
  });

  test('composition owns the HeiGIT planner without starting GPS', () async {
    final location = FakeLocationService();
    final result = await composeDependencies(
      config: const RoutingTestConfig(),
      openStorage: () => SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      ),
      createLocation: () => location,
    );
    final planner = result.dependencies.routePlanner;
    try {
      expect(planner, isA<OpenRouteServicePlanner>());
      expect(planner.available, isTrue);
      expect(location.starts, 0);
    } finally {
      await result.dependencies.dispose();
    }
    expect(planner.available, isFalse);
  });
}
