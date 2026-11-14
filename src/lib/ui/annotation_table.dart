import 'dart:math' as math;

import 'package:flutter/material.dart' hide Interval;

import '../domain/models.dart';
import '../localization/app_strings.dart';

typedef AnnotationValueChanged = void Function(
  AttributeId attributeId,
  ValueId? valueId,
);

final class AnnotationTable extends StatelessWidget {
  const AnnotationTable({
    required this.template,
    required this.interval,
    required this.onChanged,
    super.key,
  });

  final ObservationTemplate template;
  final Interval interval;
  final AnnotationValueChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final attributes = template.attributes.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    if (attributes.isEmpty) {
      return Text(context.strings.text('annotation_no_attributes'));
    }
    final valueRowCount = attributes.fold<int>(
      0,
      (largest, attribute) => math.max(largest, attribute.values.length),
    );

    return Table(
      key: const ValueKey<String>('annotation-table'),
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: 0.45),
      ),
      defaultColumnWidth: const FlexColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: <TableRow>[
        TableRow(
          children: attributes
              .map((attribute) => _HeaderCell(attribute: attribute))
              .toList(),
        ),
        for (var row = 0; row < valueRowCount; row++)
          TableRow(
            children: attributes.map((attribute) {
              if (row >= attribute.values.length) {
                return const SizedBox(height: 28);
              }
              final value = attribute.values[row];
              final selected = interval[attribute.id] == value.id;
              return _ValueCell(
                key: ValueKey<String>('annotation-${attribute.id}-${value.id}'),
                value: value,
                selected: selected,
                onTap: () =>
                    onChanged(attribute.id, selected ? null : value.id),
              );
            }).toList(),
          ),
      ],
    );
  }
}

final class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.attribute});

  final ObservationAttribute attribute;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: ValueKey<String>('annotation-header-${attribute.id}'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Text(
          attribute.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

final class _ValueCell extends StatelessWidget {
  const _ValueCell({
    required this.value,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ObservationValue value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.primary : colors.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: Text(
                value.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.onPrimary : colors.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
