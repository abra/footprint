import 'dart:async';
import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:geocoding_repository/geocoding_repository.dart';
import 'package:location_service/location_service.dart';
import 'package:map/map.dart';
import 'package:route_list/route_list.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // final locationGranted = await checkPermission(Permission.location);
    // final notificationsGranted = await checkPermission(Permission.notification);
    //
    // // TODO: If one of permissions is denied, log it and show icon in app bar
    // if (!locationGranted) log('Error: Access to location is denied!');
    // if (!notificationsGranted) log('Error: Access to notifications is denied!');
    //
    runApp(FootprintApp());
    // runApp(FootprintApp());
  }, (error, stack) {
    log('--- Uncaught error: $error\n$stack');
    // send uncaught error to crashlytics
  });
}

// Future<bool> checkPermission(Permission permission) async {
//   var status = await permission.status;
//
//   if (status.isGranted) return true;
//
//   if (status.isDenied) {
//     status = await permission.request();
//     if (status.isGranted) return true;
//   }
//
//   if (status.isPermanentlyDenied) {
//     await openAppSettings();
//     status = await permission.status;
//     return status.isGranted;
//   }
//
//   return false;
// }

// Future<bool> checkPermission(Permission permission) async {
//   // Проверяем текущий статус разрешения
//   var status = await permission.status;
//
//   if (status.isGranted) {
//     return true; // Разрешение предоставлено, продолжаем работу
//   } else if (status.isDenied) {
//     // Запрашиваем разрешение
//     status = await permission.request();
//
//     if (status.isGranted) {
//       return true; // Разрешение предоставлено после запроса
//     } else if (status.isPermanentlyDenied) {
//       // Открываем настройки приложения
//       await openAppSettings();
//
//       // Проверяем статус после открытия настроек
//       status = await permission.status;
//
//       if (status.isPermanentlyDenied) {
//         return false; // Разрешение все еще не предоставлено, возвращаем ошибку
//       }
//
//       return status.isGranted;
//     } else {
//       return false; // Разрешение не предоставлено
//     }
//   } else if (status.isPermanentlyDenied) {
//     // Если разрешение было ранее навсегда отклонено, открываем настройки
//     await openAppSettings();
//
//     // Проверяем статус после открытия настроек
//     status = await permission.status;
//
//     if (status.isPermanentlyDenied) {
//       return false; // Разрешение все еще не предоставлено, возвращаем ошибку
//     }
//
//     return status.isGranted;
//   }
//
//   return false; // Если ни одно из условий не выполнено, возвращаем ошибку
// }

class FootprintApp extends StatelessWidget {
  FootprintApp({
    super.key,
  });

  final _locationService = LocationService();
  final _routesRepository = RoutesRepository();
  final _sqliteStorage = SqliteStorage();
  late final _geocodingRepository = GeocodingRepository(
    sqliteStorage: _sqliteStorage,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomeScreen(
          pages: [
            MapScreen(
              locationService: _locationService,
              routesRepository: _routesRepository,
              geocodingRepository: _geocodingRepository,
              onPageChangeRequested: () => _PageManager.goToPage(
                _Pages.routeList,
              ),
            ),
            RouteListScreen(
              routesRepository: _routesRepository,
              onPageChangeRequested: () => _PageManager.goToPage(
                _Pages.map,
              ),
              // onRouteSelected: (routeId) {
              //   MaterialPage(
              //     name: 'route-details',
              //     child: RouteDetailsScreen(
              //       routeId: routeId,
              //       routeRepository: _routeRepository,
              //     ),
              //   );
              // }
            ),
          ],
        ),
      );
}

/// Home screen of FootprintApp
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.pages,
  });

  final List<Widget> pages;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: PageView(
          allowImplicitScrolling: true,
          physics: const NeverScrollableScrollPhysics(),
          controller: _PageManager.pageController,
          children: widget.pages,
        ),
      );

  @override
  void dispose() {
    _PageManager.pageController.dispose();
    super.dispose();
  }
}

abstract class _Pages {
  static const int map = 0;
  static const int routeList = 1;
}

/// Page controller for switching between pages at _HomeScreen of FootprintApp
class _PageManager {
  static final PageController _pageController = PageController(
    initialPage: _Pages.map,
  );

  static PageController get pageController => _pageController;

  static Future<void> goToPage(int pageIndex) async {
    await _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linearToEaseOut,
    );
  }
}
