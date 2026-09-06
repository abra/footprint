import 'package:domain_models/domain_models.dart';

enum LocationTaskMessageType { location, error, ready, stopped }

class LocationTaskMessage {
  const LocationTaskMessage._({required this.type, this.location, this.error});

  final LocationTaskMessageType type;
  final LocationDM? location;
  final Exception? error;

  static Map<String, Object?> forLocation(LocationDM location) => {
    'type': 'location',
    'data': location.toMap(),
  };

  static Map<String, Object?> forError(Object error) => {
    'type': 'error',
    'message': error.toString(),
  };

  static Map<String, Object?> ready() => {'type': 'ready'};
  static Map<String, Object?> stopped([Object? error]) => {
    'type': 'stopped',
    if (error != null) 'message': error.toString(),
  };

  factory LocationTaskMessage.decode(Object data) {
    if (data is! Map) throw const FormatException('Invalid location message.');
    return switch (data['type']) {
      'location' => LocationTaskMessage._(
        type: LocationTaskMessageType.location,
        location: LocationDM.fromMap(
          Map<String, dynamic>.from(data['data'] as Map),
        ),
      ),
      'error' => LocationTaskMessage._(
        type: LocationTaskMessageType.error,
        error: Exception(data['message'] as String),
      ),
      'ready' => const LocationTaskMessage._(
        type: LocationTaskMessageType.ready,
      ),
      'stopped' => LocationTaskMessage._(
        type: LocationTaskMessageType.stopped,
        error: data['message'] == null
            ? null
            : Exception(data['message'] as String),
      ),
      _ => throw const FormatException('Unknown location message type.'),
    };
  }
}
