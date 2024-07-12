import 'package:flutter/foundation.dart';
import 'package:local_storage/local_storage.dart';

class RoutesRepository {
  const RoutesRepository({
    @visibleForTesting LocalStorage? localStorage,
  }) : _localStorage = localStorage ?? const LocalStorage();

  final LocalStorage _localStorage;
}
