<p align="center">
  <img width="200" height="200" src="https://github.com/abra/footprint/assets/55690/ffc51268-b16c-4160-88ec-7645ef3ccbf9">
  <br/>
  🚧 Currently under development 🚧
</p>

# Footprint

Footprint allows you to record, save and share your route

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

 - [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) + [ValueListenableBuilder](https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html) for a state managing
