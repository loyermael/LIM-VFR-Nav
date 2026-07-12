import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/location_service.dart';
import 'services/chart_repository.dart';
import 'services/storage_service.dart';
import 'state/nav_state.dart';
import 'state/chart_state.dart';
import 'state/annotation_state.dart';
import 'state/tools_state.dart';
import 'state/waypoint_state.dart';
import 'state/direct_to_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the screen alive and locked to the device orientation the pilot
  // chooses in the cockpit; a moving map that dims mid-flight is dangerous.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final storage = StorageService();
  await storage.init();

  final chartRepository = ChartRepository(storage);
  final locationService = LocationService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<ChartRepository>.value(value: chartRepository),
        ChangeNotifierProvider(
          create: (_) => ChartState(chartRepository)..restoreLastChart(),
        ),
        ChangeNotifierProvider(
          create: (_) => NavState(locationService)..start(),
        ),
        ChangeNotifierProvider(
          create: (_) => AnnotationState(storage),
        ),
        ChangeNotifierProvider(
          create: (_) => WaypointState(storage),
        ),
        ChangeNotifierProvider(create: (_) => DirectToState()),
        ChangeNotifierProvider(create: (_) => ToolsState(storage)),
      ],
      child: const LimVfrNavApp(),
    ),
  );
}
