import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:osm_nominatim/osm_nominatim.dart';

import 'utils/address_builder.dart';

typedef AddressLookup = Future<String?> Function(
  double latitude,
  double longitude,
);

class GeocodingService {
  GeocodingService({
    this._platformLookup,
    this._fallbackLookup,
    http.Client Function()? createClient,
    this.fallbackInterval = const Duration(milliseconds: 1200),
    this.lookupTimeout = const Duration(seconds: 8),
  }) : _createClient = createClient ?? http.Client.new;

  final AddressLookup? _platformLookup;
  final AddressLookup? _fallbackLookup;
  final http.Client Function() _createClient;
  final Duration fallbackInterval;
  final Duration lookupTimeout;
  late final _geocoding = Geocoding();
  final _builder = AddressBuilder();
  bool _disposed = false;
  void Function()? _cancelCurrent;
  _AddressRequest? _pending;
  Future<void>? _draining;
  Future<void>? _disposal;
  DateTime? _lastFallback;
  http.Client? _client;

  /// One request may run; only the newest waiting coordinate is retained.
  Future<String?> reverseGeocoding({
    required double latitude,
    required double longitude,
  }) {
    if (_disposed) return Future.value();
    final request = _AddressRequest(latitude, longitude);
    _pending?.result.complete(null);
    _pending = request;
    _draining ??= _drain();
    return request.result.future;
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final request = _pending!;
        _pending = null;
        try {
          request.result.complete(await _lookup(request));
        } on Object catch (error, stack) {
          request.result.completeError(error, stack);
        }
      }
    } finally {
      _draining = null;
    }
  }

  Future<String?> _bounded(Future<String?> result) {
    final completion = Completer<String?>();
    final timer = Timer(lookupTimeout, () {
      if (!completion.isCompleted) {
        completion.completeError(
          TimeoutException('Geocoding timed out.', lookupTimeout),
        );
      }
    });
    void cancel() {
      if (!completion.isCompleted) completion.complete(null);
    }

    _cancelCurrent = cancel;
    unawaited(
      result.then<void>(
        (value) {
          if (!completion.isCompleted) completion.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!completion.isCompleted) completion.completeError(error, stack);
        },
      ),
    );
    return completion.future.whenComplete(() {
      timer.cancel();
      if (identical(_cancelCurrent, cancel)) _cancelCurrent = null;
    });
  }

  Future<void> _delay(Duration duration) {
    final completion = Completer<void>();
    final timer = Timer(duration, completion.complete);
    void cancel() {
      if (!completion.isCompleted) completion.complete();
    }

    _cancelCurrent = cancel;
    return completion.future.whenComplete(() {
      timer.cancel();
      if (identical(_cancelCurrent, cancel)) _cancelCurrent = null;
    });
  }

  Future<String?> _lookup(_AddressRequest request) async {
    try {
      final address = await _bounded(
        (_platformLookup ?? _platformAddress)(
          request.latitude,
          request.longitude,
        ),
      );
      if (address != null && address.isNotEmpty) return address;
    } on Exception {
      // Platform geocoders may be unavailable, rate limited, or unresponsive.
    }
    if (_disposed) return null;
    final last = _lastFallback;
    if (last != null) {
      final remaining = fallbackInterval - DateTime.now().difference(last);
      if (remaining > Duration.zero) {
        await _delay(remaining);
      }
    }
    if (_disposed) return null;
    _lastFallback = DateTime.now();
    return _bounded(
      (_fallbackLookup ?? _fallbackAddress)(
        request.latitude,
        request.longitude,
      ),
    );
  }

  Future<String?> _platformAddress(double latitude, double longitude) async {
    final placemarks = await _geocoding.placemarkFromCoordinates(
      latitude,
      longitude,
    );
    final placemark = placemarks.firstOrNull;
    return placemark == null
        ? null
        : _builder.buildAddressFromPlacemark(placemark);
  }

  Future<String?> _fallbackAddress(double latitude, double longitude) async {
    final client = _createClient();
    _client = client;
    try {
      final response = await client
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {
              'format': 'jsonv2',
              'lat': '$latitude',
              'lon': '$longitude',
              'addressdetails': '1',
              'namedetails': '1',
            }),
            headers: {'User-Agent': 'io.github.abra.footprint'},
          )
          .timeout(lookupTimeout);
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Geocoding returned HTTP ${response.statusCode}.',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey('error')) return null;
      return _builder.buildAddressFromNominatim(Place.fromJson(json));
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _cancelCurrent?.call();
    _pending?.result.complete(null);
    _pending = null;
    _client?.close();
    await _draining;
  }
}

class _AddressRequest {
  _AddressRequest(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  final result = Completer<String?>();
}
