import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import 'export_screen.dart';
import 'queries_screen.dart';
import 'templates_screen.dart';
import 'videos_screen.dart';

final class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (!widget.controller.initialized && widget.controller.error == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final pages = <Widget>[
        VideosScreen(controller: widget.controller),
        TemplatesScreen(controller: widget.controller),
        QueriesScreen(controller: widget.controller),
        ExportScreen(controller: widget.controller),
      ];
      return Scaffold(
        body: Column(
          children: <Widget>[
            if (widget.controller.error != null)
              MaterialBanner(
                content: Text(widget.controller.error!),
                actions: <Widget>[
                  TextButton(
                    onPressed: widget.controller.clearError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            Expanded(
              child: Row(
                children: <Widget>[
                  NavigationRail(
                    extended: MediaQuery.sizeOf(context).width >= 1050,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) =>
                        setState(() => selectedIndex = value),
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.video_camera_back, size: 32),
                    ),
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: Icon(Icons.video_library_outlined),
                        selectedIcon: Icon(Icons.video_library),
                        label: Text('Videos'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.view_list_outlined),
                        selectedIcon: Icon(Icons.view_list),
                        label: Text('Templates'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.query_stats_outlined),
                        selectedIcon: Icon(Icons.query_stats),
                        label: Text('Queries'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.archive_outlined),
                        selectedIcon: Icon(Icons.archive),
                        label: Text('Export'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(index: selectedIndex, children: pages),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
