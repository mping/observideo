import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/query_service.dart';

final class QueriesScreen extends StatefulWidget {
  const QueriesScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<QueriesScreen> createState() => _QueriesScreenState();
}

final class _QueriesScreenState extends State<QueriesScreen> {
  String? templateId;
  QueryAggregator aggregator = QueryAggregator.identity;
  final top = <int, int?>{};
  final bottom = <int, int?>{};
  List<CombinedQueryRow> rows = const <CombinedQueryRow>[];

  @override
  Widget build(BuildContext context) {
    final templates = widget.controller.database.templates;
    if (templates.every((template) => template.id != templateId)) {
      templateId = templates.isEmpty ? null : templates.first.id;
      top.clear();
      bottom.clear();
      rows = const <CombinedQueryRow>[];
    }
    final template = templateId == null
        ? null
        : widget.controller.database.findTemplate(templateId!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Queries', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          if (template == null)
            const Expanded(
              child: Center(child: Text('Create a template first.')),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: template.id,
                    decoration: const InputDecoration(
                      labelText: 'Template',
                      border: OutlineInputBorder(),
                    ),
                    items: templates
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      templateId = value;
                      top.clear();
                      bottom.clear();
                      rows = const <CombinedQueryRow>[];
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                SegmentedButton<QueryAggregator>(
                  segments: const <ButtonSegment<QueryAggregator>>[
                    ButtonSegment<QueryAggregator>(
                      value: QueryAggregator.identity,
                      label: Text('Per video'),
                    ),
                    ButtonSegment<QueryAggregator>(
                      value: QueryAggregator.byPrefix,
                      label: Text('Group by 8-char prefix'),
                    ),
                  ],
                  selected: <QueryAggregator>{aggregator},
                  onSelectionChanged: (value) =>
                      setState(() => aggregator = value.single),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _SelectionPanel(
                      title: 'Numerator',
                      template: template,
                      selection: top,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SelectionPanel(
                      title: 'Denominator',
                      template: template,
                      selection: bottom,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Card.outlined(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  'Results',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: _run,
                                  child: const Text('Run query'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Export CSV',
                                  onPressed: rows.isEmpty
                                      ? null
                                      : () => _export(template),
                                  icon: const Icon(Icons.save_alt),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: rows.isEmpty
                                ? const Center(
                                    child: Text('No positive matches.'),
                                  )
                                : ListView.builder(
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) {
                                      final row = rows[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(row.name),
                                        trailing: Text(
                                          '${row.topMatched} / ${row.bottomMatched} '
                                          '(total ${row.total})',
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _run() {
    final service = widget.controller.queryService;
    final topTally = service.runQuery(
      widget.controller.database.videos,
      templateId!,
      aggregator,
      top,
    );
    final bottomTally = service.runQuery(
      widget.controller.database.videos,
      templateId!,
      aggregator,
      bottom,
    );
    setState(() => rows = service.combine(topTally, bottomTally));
  }

  Future<void> _export(ObservationTemplate template) async {
    final location = await getSaveLocation(
      suggestedName: 'observideo-query.csv',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'CSV', extensions: <String>['csv']),
      ],
    );
    if (location == null) return;
    final outcome = await widget.controller.exportService.exportQueryCsv(
      _selectionRow('Numerator', template, top),
      _selectionRow('Denominator', template, bottom),
      rows,
      location.path,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(outcome.ok ? 'Query exported.' : outcome.error!)),
    );
  }

  List<String> _selectionRow(
    String label,
    ObservationTemplate template,
    QuerySelection selection,
  ) => <String>[
    label,
    for (final attribute in template.attributes)
      '${attribute.name}: '
          '${attribute.findValue(selection[attribute.id] ?? -1)?.name ?? 'Any'}',
  ];
}

final class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    required this.title,
    required this.template,
    required this.selection,
    required this.onChanged,
  });

  final String title;
  final ObservationTemplate template;
  final QuerySelection selection;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final attribute in template.attributes) ...<Widget>[
          DropdownButtonFormField<int?>(
            initialValue: selection[attribute.id],
            decoration: InputDecoration(
              labelText: attribute.name,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(value: null, child: Text('Any')),
              ...attribute.values.map(
                (value) => DropdownMenuItem<int?>(
                  value: value.id,
                  child: Text(value.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              selection[attribute.id] = value;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}
