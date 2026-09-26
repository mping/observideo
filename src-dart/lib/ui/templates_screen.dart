import 'package:flutter/material.dart';

import '../domain/models.dart';
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
                'Templates',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addTemplate,
                icon: const Icon(Icons.add),
                label: const Text('New template'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (selected == null)
            const Expanded(child: Center(child: Text('No templates.')))
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selected.id,
                    decoration: const InputDecoration(
                      labelText: 'Template',
                      border: OutlineInputBorder(),
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
                  tooltip: 'Rename template',
                  onPressed: () => _renameTemplate(selected),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'Delete template',
                  onPressed: () => _deleteTemplate(selected),
                  icon: const Icon(Icons.delete_outline),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 190,
                  child: TextFormField(
                    key: ValueKey('${selected.id}-${selected.intervalMs}'),
                    initialValue: (selected.intervalMs / 1000).toString(),
                    decoration: const InputDecoration(
                      labelText: 'Interval (seconds)',
                      border: OutlineInputBorder(),
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
              child: ListView.separated(
                itemCount: selected.attributes.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == selected.attributes.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _addAttribute(selected),
                        icon: const Icon(Icons.add),
                        label: const Text('Add attribute'),
                      ),
                    );
                  }
                  return _AttributeCard(
                    controller: widget.controller,
                    template: selected,
                    attribute: selected.attributes[index],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTemplate() async {
    final name = await askForText(context, 'New template', 'Template name');
    if (name == null || name.trim().isEmpty) return;
    final id = widget.controller.addTemplate(name.trim(), 15000);
    setState(() => selectedId = id);
  }

  Future<void> _renameTemplate(ObservationTemplate template) async {
    final name = await askForText(
      context,
      'Rename template',
      'Template name',
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
          title: const Text('Template is in use'),
          content: SizedBox(
            width: 560,
            child: Text(
              'Remove the template from these videos first:\n\n${users.join('\n')}',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await confirm(
      context,
      'Delete template?',
      "Delete '${template.name}'? This cannot be undone.",
    );
    if (confirmed) widget.controller.deleteTemplate(template.id);
  }

  Future<void> _addAttribute(ObservationTemplate template) async {
    final name = await askForText(context, 'Add attribute', 'Attribute name');
    if (name != null && name.trim().isNotEmpty) {
      widget.controller.addAttribute(template.id, name.trim());
    }
  }
}

final class _AttributeCard extends StatelessWidget {
  const _AttributeCard({
    required this.controller,
    required this.template,
    required this.attribute,
  });

  final AppController controller;
  final ObservationTemplate template;
  final ObservationAttribute attribute;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                attribute.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Rename attribute',
                onPressed: () async {
                  final name = await askForText(
                    context,
                    'Rename attribute',
                    'Attribute name',
                    initialValue: attribute.name,
                  );
                  if (name != null && name.trim().isNotEmpty) {
                    controller.renameAttribute(
                      template.id,
                      attribute.id,
                      name.trim(),
                    );
                  }
                },
                icon: const Icon(Icons.edit, size: 20),
              ),
              IconButton(
                tooltip: 'Delete attribute',
                onPressed: () => _deleteAttribute(context),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final value in attribute.values)
                InputChip(
                  label: Text(value.name),
                  onPressed: () => _renameValue(context, value),
                  onDeleted: () => _deleteValue(context, value),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add value'),
                onPressed: () => _addValue(context),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _deleteAttribute(BuildContext context) async {
    final usage = controller.attributeUsageCount(template.id, attribute.id);
    final confirmed =
        usage == 0 ||
        await confirm(
          context,
          'Delete attribute?',
          '$usage annotated intervals use this attribute. Deleting it clears '
              'those selections.',
        );
    if (confirmed) controller.deleteAttribute(template.id, attribute.id);
  }

  Future<void> _addValue(BuildContext context) async {
    final name = await askForText(context, 'Add value', 'Value name');
    if (name != null && name.trim().isNotEmpty) {
      controller.addValue(template.id, attribute.id, name.trim());
    }
  }

  Future<void> _renameValue(
    BuildContext context,
    ObservationValue value,
  ) async {
    final name = await askForText(
      context,
      'Rename value',
      'Value name',
      initialValue: value.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.renameValue(template.id, attribute.id, value.id, name.trim());
    }
  }

  Future<void> _deleteValue(
    BuildContext context,
    ObservationValue value,
  ) async {
    final usage = controller.valueUsageCount(
      template.id,
      attribute.id,
      value.id,
    );
    final confirmed =
        usage == 0 ||
        await confirm(
          context,
          'Delete value?',
          '$usage annotated intervals use this value. Deleting it clears '
              'those selections.',
        );
    if (confirmed) controller.deleteValue(template.id, attribute.id, value.id);
  }
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, currentValue),
          child: const Text('Save'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ??
    false;
