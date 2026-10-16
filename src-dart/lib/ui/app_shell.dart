import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
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
                    child: Text(context.strings.text('action_dismiss')),
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
                    destinations: <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: const Icon(Icons.video_library_outlined),
                        selectedIcon: const Icon(Icons.video_library),
                        label: Text(context.strings.text('navigation_videos')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.view_list_outlined),
                        selectedIcon: const Icon(Icons.view_list),
                        label: Text(
                          context.strings.text('navigation_templates'),
                        ),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.query_stats_outlined),
                        selectedIcon: const Icon(Icons.query_stats),
                        label: Text(context.strings.text('navigation_queries')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.archive_outlined),
                        selectedIcon: const Icon(Icons.archive),
                        label: Text(context.strings.text('navigation_export')),
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
