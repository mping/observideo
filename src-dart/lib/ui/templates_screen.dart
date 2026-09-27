import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../localization/app_strings.dart';
import '../services/app_controller.dart';

final class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

final class _TemplatesScreenState extends State<TemplatesScreen> {
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final templates = widget.controller.database.templates;
    if (templates.every((template) => template.id != selectedId)) {
      selectedId = templates.isEmpty ? null : templates.first.id;
    }
    final selected = selectedId == null
        ? null
        : widget.controller.database.findTemplate(selectedId!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                context.strings.text('templates_title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addTemplate,
                icon: const Icon(Icons.add),
                label: Text(context.strings.text('templates_new')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (selected == null)
            Expanded(
              child: Center(
                child: Text(context.strings.text('templates_empty')),
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selected.id,
                    decoration: InputDecoration(
                      labelText: context.strings.text('templates_label'),
                      border: const OutlineInputBorder(),
                    ),
                    items: templates
                        .map(
                          (template) => DropdownMenuItem<String>(
                            value: template.id,
                            child: Text(template.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedId = value),
                  ),
                ),
                IconButton(
                  tooltip: context.strings.text('templates_rename'),
                  onPressed: () => _renameTemplate(selected),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: context.strings.text('templates_delete'),
                  onPressed: () => _deleteTemplate(selected),
                  icon: const Icon(Icons.delete_outline),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 190,
                  child: TextFormField(
                    key: ValueKey('${selected.id}-${selected.intervalMs}'),
                    initialValue: (selected.intervalMs / 1000).toString(),
                    decoration: InputDecoration(
                      labelText: context.strings.text(
                        'templates_interval_seconds',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (value) {
                      final seconds = double.tryParse(value);
                      if (seconds != null && seconds > 0) {
                        widget.controller.setTemplateInterval(
                          selected.id,
                          (seconds * 1000).round(),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('add-template-attribute'),
                      onPressed: () => _addAttribute(selected),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.strings.text('templates_add_attribute'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (selected.attributes.isEmpty)
                    Text(context.strings.text('annotation_no_attributes'))
                  else
                    _TemplateAttributeTable(
                      controller: widget.controller,
                      template: selected,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTemplate() async {
    final name = await askForText(
      context,
      context.strings.text('templates_new_title'),
      context.strings.text('templates_name_label'),
    );
    if (name == null || name.trim().isEmpty) return;
    final id = widget.controller.addTemplate(name.trim(), 15000);
    setState(() => selectedId = id);
  }

  Future<void> _renameTemplate(ObservationTemplate template) async {
    final name = await askForText(
      context,
      context.strings.text('templates_rename_title'),
      context.strings.text('templates_name_label'),
      initialValue: template.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.controller.renameTemplate(template.id, name.trim());
    }
  }

  Future<void> _deleteTemplate(ObservationTemplate template) async {
    final users = widget.controller.videosUsingTemplate(template.id);
    if (users.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.strings.text('templates_in_use_title')),
          content: SizedBox(
            width: 560,
            child: Text(
              context.strings.text('templates_in_use_message', <String, Object>{
                'videos': users.join('\n'),
              }),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.text('action_close')),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await confirm(
      context,
      context.strings.text('templates_delete_title'),
      context.strings.text('templates_delete_message', <String, Object>{
        'name': template.name,
      }),
    );
    if (confirmed) widget.controller.deleteTemplate(template.id);
  }

  Future<void> _addAttribute(ObservationTemplate template) async {
    final name = await askForText(
      context,
      context.strings.text('templates_add_attribute_title'),
      context.strings.text('templates_attribute_name'),
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.controller.addAttribute(template.id, name.trim());
    }
  }
}

final class _TemplateAttributeTable extends StatelessWidget {
  const _TemplateAttributeTable({
    required this.controller,
    required this.template,
  });

  final AppController controller;
  final ObservationTemplate template;

  @override
  Widget build(BuildContext context) {
    final attributes = template.attributes.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final valueRowCount = attributes.fold<int>(
      0,
      (largest, attribute) => math.max(largest, attribute.values.length),
    );
    final colors = Theme.of(context).colorScheme;

    return _HorizontalTableViewport(
      minimumContentWidth: attributes.length * 150,
      child: Table(
        key: const ValueKey<String>('template-attribute-table'),
        border: TableBorder.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
        defaultColumnWidth: const FlexColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              for (final attribute in attributes)
                _AttributeHeaderCell(
                  attribute: attribute,
                  onRename: () => _renameAttribute(context, attribute),
                  onDelete: () => _deleteAttribute(context, attribute),
                ),
            ],
          ),
          for (var row = 0; row < valueRowCount; row++)
            TableRow(
              children: <Widget>[
                for (final attribute in attributes)
                  if (row < attribute.values.length)
                    _EditableValueCell(
                      key: ValueKey<String>(
                        'template-value-${attribute.id}-${attribute.values[row].id}',
                      ),
                      controller: controller,
                      template: template,
                      attribute: attribute,
                      value: attribute.values[row],
                    )
                  else
                    const SizedBox(height: 30),
              ],
            ),
          TableRow(
            children: <Widget>[
              for (final attribute in attributes)
                _AddValueCell(onPressed: () => _addValue(context, attribute)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _renameAttribute(
    BuildContext context,
    ObservationAttribute attribute,
  ) async {
    final name = await askForText(
      context,
      context.strings.text('templates_rename_attribute'),
      context.strings.text('templates_attribute_name'),
      initialValue: attribute.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.renameAttribute(template.id, attribute.id, name.trim());
    }
  }

  Future<void> _deleteAttribute(
    BuildContext context,
    ObservationAttribute attribute,
  ) async {
    final usage = controller.attributeUsageCount(template.id, attribute.id);
    final confirmed =
        usage == 0 ||
        await confirm(
          context,
          context.strings.text('templates_delete_attribute_title'),
          context.strings.text(
            'templates_delete_attribute_message',
            <String, Object>{'count': usage},
          ),
        );
    if (confirmed) controller.deleteAttribute(template.id, attribute.id);
  }

  Future<void> _addValue(
    BuildContext context,
    ObservationAttribute attribute,
  ) async {
    final name = await askForText(
      context,
      context.strings.text('templates_add_value_title'),
      context.strings.text('templates_value_name'),
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.addValue(template.id, attribute.id, name.trim());
    }
  }
}

final class _HorizontalTableViewport extends StatefulWidget {
  const _HorizontalTableViewport({
    required this.minimumContentWidth,
    required this.child,
  });

  final double minimumContentWidth;
  final Widget child;

  @override
  State<_HorizontalTableViewport> createState() =>
      _HorizontalTableViewportState();
}

final class _HorizontalTableViewportState
    extends State<_HorizontalTableViewport> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentWidth = math
          .max(constraints.maxWidth, widget.minimumContentWidth)
          .toDouble();
      final canScroll = contentWidth > constraints.maxWidth;
      return Scrollbar(
        controller: _controller,
        thumbVisibility: canScroll,
        trackVisibility: canScroll,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          key: const ValueKey<String>('template-attribute-horizontal-scroll'),
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(bottom: canScroll ? 12 : 0),
          child: SizedBox(width: contentWidth, child: widget.child),
        ),
      );
    },
  );
}

final class _AttributeHeaderCell extends StatelessWidget {
  const _AttributeHeaderCell({
    required this.attribute,
    required this.onRename,
    required this.onDelete,
  });

  final ObservationAttribute attribute;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: ValueKey<String>('template-attribute-header-${attribute.id}'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Center(
              child: Text(
                attribute.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: context.strings.text('templates_rename_attribute'),
                onPressed: onRename,
                padding: const EdgeInsets.all(1),
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.edit, size: 16),
              ),
              IconButton(
                tooltip: context.strings.text('templates_delete_attribute'),
                onPressed: onDelete,
                padding: const EdgeInsets.all(1),
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.delete_outline, size: 16),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _EditableValueCell extends StatelessWidget {
  const _EditableValueCell({
    required this.controller,
    required this.template,
    required this.attribute,
    required this.value,
    super.key,
  });

  final AppController controller;
  final ObservationTemplate template;
  final ObservationAttribute attribute;
  final ObservationValue value;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: () => _renameValue(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value.name,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.strings.text('templates_delete_value'),
          onPressed: () => _deleteValue(context),
          padding: const EdgeInsets.all(1),
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          icon: const Icon(Icons.close, size: 15),
        ),
      ],
    ),
  );

  Future<void> _renameValue(BuildContext context) async {
    final name = await askForText(
      context,
      context.strings.text('templates_rename_value'),
      context.strings.text('templates_value_name'),
      initialValue: value.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.renameValue(template.id, attribute.id, value.id, name.trim());
    }
  }

  Future<void> _deleteValue(BuildContext context) async {
    final usage = controller.valueUsageCount(
      template.id,
      attribute.id,
      value.id,
    );
    final confirmed =
        usage == 0 ||
        await confirm(
          context,
          context.strings.text('templates_delete_value_title'),
          context.strings.text(
            'templates_delete_value_message',
            <String, Object>{'count': usage},
          ),
        );
    if (confirmed) controller.deleteValue(template.id, attribute.id, value.id);
  }
}

final class _AddValueCell extends StatelessWidget {
  const _AddValueCell({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.all(1),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: Theme.of(context).textTheme.labelSmall,
    ),
    icon: const Icon(Icons.add, size: 15),
    label: Text(context.strings.text('templates_add_value')),
  );
}

Future<String?> askForText(
  BuildContext context,
  String title,
  String label, {
  String initialValue = '',
}) async {
  var currentValue = initialValue;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initialValue,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onChanged: (value) => currentValue = value,
        onFieldSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.text('action_cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, currentValue),
          child: Text(context.strings.text('action_save')),
        ),
      ],
    ),
  );
  return result;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.text('action_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.text('action_continue')),
          ),
        ],
      ),
    ) ??
    false;
