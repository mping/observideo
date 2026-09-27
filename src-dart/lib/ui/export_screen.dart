import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
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
              Text(
                context.strings.text('export_title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.strings.text('export_annotated_videos'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.strings.text('export_summary', <String, Object>{
                          'count': count,
                        }),
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<ExportValueMode>(
                        segments: <ButtonSegment<ExportValueMode>>[
                          ButtonSegment<ExportValueMode>(
                            value: ExportValueMode.name,
                            label: Text(
                              context.strings.text('export_value_names'),
                            ),
                          ),
                          ButtonSegment<ExportValueMode>(
                            value: ExportValueMode.oneBasedIndex,
                            label: Text(
                              context.strings.text('export_one_based_indexes'),
                            ),
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
                        label: Text(
                          exporting
                              ? context.strings.text('export_in_progress')
                              : context.strings.text('export_zip'),
                        ),
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
      suggestedName: context.strings.text('export_file_name'),
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: context.strings.text('export_file_type'),
          extensions: const <String>['zip'],
        ),
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
      SnackBar(
        content: Text(
          outcome.ok ? context.strings.text('export_complete') : outcome.error!,
        ),
      ),
    );
  }
}
