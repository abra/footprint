# Footprint

Footprint allows you to record, save and share your route

[Footprint](https://github.com/abra/footprint)

## Tech stack

### Packages

- [flutter_map](https://pub.dev/packages/flutter_map) - A versatile mapping package for Flutter
  
- [flutter_map_animations](https://pub.dev/packages/flutter_map_animations) - Animation utilities for markers and controls of the flutter_map package

- [geolocator](https://pub.dev/packages/geolocator) - Geolocation plugin for Flutter. This plugin provides a cross-platform API for generic location (GPS etc.) functions 

- [sqflite](https://pub.dev/packages/sqflite) - Flutter plugin for SQLite, a self-contained, high-reliability, embedded, SQL database engine

### Architecture

 - Clean Architecture (mixed approach)
   
   - Layers are used for files that aren't tied to a single feature (database, network,...)
  
   - Features are used for files that are rarely used (screens, state managers,....)
 
 - Repository Pattern
 
 - MVVM

 - [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) + [ValueListenableBuilder](https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html) for a state managing
