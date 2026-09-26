import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/export_service.dart';

final class ExportScreen extends StatefulWidget {
  const ExportScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

final class _ExportScreenState extends State<ExportScreen> {
  ExportValueMode mode = ExportValueMode.name;
  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.database.videos
        .where((video) => !video.missing && video.annotation != null)
        .length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Export', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Annotated videos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$count videos will be written to one ZIP archive, with '
                        'one RFC 4180 CSV file per video.',
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<ExportValueMode>(
                        segments: const <ButtonSegment<ExportValueMode>>[
                          ButtonSegment<ExportValueMode>(
                            value: ExportValueMode.name,
                            label: Text('Value names'),
                          ),
                          ButtonSegment<ExportValueMode>(
                            value: ExportValueMode.oneBasedIndex,
                            label: Text('1-based indexes'),
                          ),
                        ],
                        selected: <ExportValueMode>{mode},
                        onSelectionChanged: (values) =>
                            setState(() => mode = values.single),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: exporting || count == 0 ? null : _export,
                        icon: const Icon(Icons.archive),
                        label: Text(exporting ? 'Exporting…' : 'Export ZIP'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    final location = await getSaveLocation(
      suggestedName: 'observideo-annotations.zip',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'ZIP archive', extensions: <String>['zip']),
      ],
    );
    if (location == null) return;
    setState(() => exporting = true);
    final outcome = await widget.controller.exportService.exportAllToZip(
      widget.controller.database,
      mode,
      location.path,
    );
    if (!mounted) return;
    setState(() => exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(outcome.ok ? 'Export complete.' : outcome.error!)),
    );
  }
}
