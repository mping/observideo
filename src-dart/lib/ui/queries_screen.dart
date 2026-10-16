import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../localization/app_strings.dart';
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
          Text(
            context.strings.text('queries_title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          if (template == null)
            Expanded(
              child: Center(
                child: Text(context.strings.text('queries_create_template')),
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: template.id,
                    decoration: InputDecoration(
                      labelText: context.strings.text('templates_label'),
                      border: const OutlineInputBorder(),
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
                  segments: <ButtonSegment<QueryAggregator>>[
                    ButtonSegment<QueryAggregator>(
                      value: QueryAggregator.identity,
                      label: Text(context.strings.text('queries_per_video')),
                    ),
                    ButtonSegment<QueryAggregator>(
                      value: QueryAggregator.byPrefix,
                      label: Text(context.strings.text('queries_group_prefix')),
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
                      title: context.strings.text('queries_numerator'),
                      template: template,
                      selection: top,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SelectionPanel(
                      title: context.strings.text('queries_denominator'),
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
                                  context.strings.text('queries_results'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: _run,
                                  child: Text(
                                    context.strings.text('queries_run'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: context.strings.text(
                                    'queries_export_csv',
                                  ),
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
                                ? Center(
                                    child: Text(
                                      context.strings.text(
                                        'queries_no_matches',
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) {
                                      final row = rows[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(row.name),
                                        trailing: Text(
                                          context.strings.text(
                                            'queries_result_count',
                                            <String, Object>{
                                              'top': row.topMatched,
                                              'bottom': row.bottomMatched,
                                              'total': row.total,
                                            },
                                          ),
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
    final strings = context.strings;
    final numeratorRow = _selectionRow(
      strings,
      strings.text('queries_numerator'),
      template,
      top,
    );
    final denominatorRow = _selectionRow(
      strings,
      strings.text('queries_denominator'),
      template,
      bottom,
    );
    final location = await getSaveLocation(
      suggestedName: strings.text('queries_file_name'),
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: strings.text('queries_file_type'),
          extensions: const <String>['csv'],
        ),
      ],
    );
    if (location == null) return;
    final outcome = await widget.controller.exportService.exportQueryCsv(
      numeratorRow,
      denominatorRow,
      rows,
      location.path,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.ok ? strings.text('queries_exported') : outcome.error!,
        ),
      ),
    );
  }

  List<String> _selectionRow(
    AppStrings strings,
    String label,
    ObservationTemplate template,
    QuerySelection selection,
  ) => <String>[
    label,
    for (final attribute in template.attributes)
      strings.text('queries_selection', <String, Object>{
        'attribute': attribute.name,
        'value':
            attribute.findValue(selection[attribute.id] ?? -1)?.name ??
            strings.text('action_any'),
      }),
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
              DropdownMenuItem<int?>(
                value: null,
                child: Text(context.strings.text('action_any')),
              ),
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
