import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:osm_nominatim/osm_nominatim.dart';

// TODO: Refactor the following code
class GeocodingService {
  GeocodingService();

  static DateTime? _lastNominatimCall;

  Future<Placemark?> getPlacemark({
    required double lat,
    required double lon,
  }) async {
    try {
      // Попытка получить данные через geocoding
      final placemarkList = await placemarkFromCoordinates(lat, lon);
      if (placemarkList.isNotEmpty) {
        return placemarkList.first;
      }
    } on Exception catch (e) {
      // Если произошла ошибка с превышением лимита запросов или другая ошибка
      return await _getPlacemarkFromNominatim(lat, lon);
    }

    // Если данные не были получены через geocoding, используем Nominatim
    return await _getPlacemarkFromNominatim(lat, lon);
  }

  Future<Placemark?> _getPlacemarkFromNominatim(double lat, double lon) async {
    // Проверка на соблюдение лимита запросов (не чаще 1 раза в секунду)
    if (_lastNominatimCall != null) {
      final timeSinceLastCall = DateTime.now().difference(_lastNominatimCall!);
      if (timeSinceLastCall.inSeconds < 1) {
        await Future.delayed(
          Duration(seconds: 1 - timeSinceLastCall.inSeconds),
        );
      }
    }

    // Выполняем запрос к osm_nominatim
    final reverseSearch = await Nominatim.reverseSearch(
      lat: lat,
      lon: lon,
      addressDetails: true,
    );

    _lastNominatimCall = DateTime.now();

    // Преобразование ответа osm_nominatim в Placemark
    if (reverseSearch.address != null) {
      final Map<String, dynamic> address = reverseSearch.address!;

      return Placemark(
        street: _buildStreet(
          address['road'],
          address['houseNumber'],
          address['houseName'],
        ),
        subThoroughfare: address['houseNumber'],
        thoroughfare: address['road'],
        subLocality: address['suburb'] ??
            address['borough'] ??
            address['neighbourhood'] ??
            address['quarter'] ??
            address['cityDistrict'],
        locality: address['city'] ??
            address['town'] ??
            address['village'] ??
            address['hamlet'],
        subAdministrativeArea: address['county'] ??
            address['district'] ??
            address['stateDistrict'] ??
            address['municipality'],
        administrativeArea: address['state'] ?? address['region'],
        postalCode: address['postcode'],
        country: address['country'],
      );
    }

    return null;
  }

  String? _buildStreet(String? road, String? houseNumber, String? houseName) {
    if (houseName != null) {
      return houseName;
    }
    if (houseNumber != null && road != null) {
      return '$road, $houseNumber';
    }
    return road;
  }
}
