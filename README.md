<p align="center">
  🚧 Currently under development 🚧
</p>
<h1 align="center">
  <img width="200" height="200" src="https://github.com/abra/footprint/assets/55690/ffc51268-b16c-4160-88ec-7645ef3ccbf9">
  <br/>Footprint
</h1>
<p align="center">
  Footprint allows you to record, save and share your route
</p>


## Tech Stack

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

 - [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) + [ValueListenableBuilder](https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html) for a state management

## App Interface

<div align="center">
  <img src="https://github.com/user-attachments/assets/9a68be7b-a3f6-4abb-880a-922ed863d4d8" width="200">
  <img src="https://github.com/user-attachments/assets/078d4fe2-652c-4080-b464-0bfed80e21c0" width="200">
  <img src="https://github.com/user-attachments/assets/74fb7faa-88b5-465a-849b-2b529eedc8b9" width="200">
  <img src="https://github.com/user-attachments/assets/09038033-7de1-4993-afc4-68efba39b71f" width="200">
</div>
