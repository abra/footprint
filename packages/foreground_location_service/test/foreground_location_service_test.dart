import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/src/location_task_message.dart';

void main() {
  test('location message survives isolate-compatible map round trip', () {
    final location = LocationDM(
      id: 'point',
      latitude: 56,
      longitude: 60,
      timestamp: DateTime.utc(2026, 9, 6),
    );
    final message = LocationTaskMessage.decode(
      LocationTaskMessage.forLocation(location),
    );
    expect(message.location, location);
    expect(message.error, isNull);
  });

  test(
    'error message preserves its first character and special characters',
    () {
      final error = Exception('Permission denied: {location}');
      final message = LocationTaskMessage.decode(
        LocationTaskMessage.forError(error),
      );
      expect(message.error.toString(), contains(error.toString()));
      expect(message.location, isNull);
    },
  );

  test('malformed messages are rejected explicitly', () {
    expect(() => LocationTaskMessage.decode('Error:{}'), throwsFormatException);
    expect(
      () => LocationTaskMessage.decode({'type': 'unknown'}),
      throwsFormatException,
    );
  });
}
