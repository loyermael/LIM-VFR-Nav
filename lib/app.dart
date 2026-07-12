import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/tools_state.dart';
import 'features/map/map_screen.dart';

class LimVfrNavApp extends StatelessWidget {
  const LimVfrNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Night mode is a global UI concern, so it lives on ToolsState and drives
    // the whole MaterialApp theme rather than a single screen.
    final nightMode = context.select<ToolsState, bool>((t) => t.nightMode);
    return MaterialApp(
      title: 'L!M VFR Nav',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.day,
      darkTheme: AppTheme.night,
      themeMode: nightMode ? ThemeMode.dark : ThemeMode.light,
      home: const MapScreen(),
    );
  }
}
