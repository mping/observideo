import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../services/app_log.dart';

final class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({required this.log, super.key});

  final AppLog log;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

final class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  LogLevel minimum = LogLevel.info;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.strings.text('diagnostics_title')),
      actions: <Widget>[
        IconButton(
          tooltip: context.strings.text('diagnostics_copy'),
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: _copy,
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.log,
      builder: (context, _) {
        final entries = widget.log.entries
            .where((entry) => entry.level.index >= minimum.index)
            .toList();
        final filePath = widget.log.filePath;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SegmentedButton<LogLevel>(
                    segments: <ButtonSegment<LogLevel>>[
                      ButtonSegment<LogLevel>(
                        value: LogLevel.info,
                        label: Text(
                          context.strings.text('diagnostics_filter_all'),
                        ),
                      ),
                      ButtonSegment<LogLevel>(
                        value: LogLevel.warning,
                        label: Text(
                          context.strings.text('diagnostics_filter_warnings'),
                        ),
                      ),
                      ButtonSegment<LogLevel>(
                        value: LogLevel.error,
                        label: Text(
                          context.strings.text('diagnostics_filter_errors'),
                        ),
                      ),
                    ],
                    selected: <LogLevel>{minimum},
                    onSelectionChanged: (values) =>
                        setState(() => minimum = values.single),
                  ),
                  if (filePath != null)
                    SelectableText(
                      context.strings.text(
                        'diagnostics_log_file',
                        <String, Object>{'path': filePath},
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(context.strings.text('diagnostics_empty')),
                    )
                  : SelectionArea(
                      child: ListView.builder(
                        // Newest entry at the bottom, kept in view as entries
                        // arrive.
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _LogRow(entry: entries[entries.length - 1 - index]),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.log.entries.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.text('diagnostics_copied'))),
    );
  }
}

final class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, color) = switch (entry.level) {
      LogLevel.info => (Icons.info_outline, colors.onSurfaceVariant),
      LogLevel.warning => (Icons.warning_amber, Colors.amber.shade800),
      LogLevel.error => (Icons.error_outline, colors.error),
    };
    final style = theme.textTheme.bodySmall!.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Menlo', 'Consolas'],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.clock,
            style: style.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              entry.source,
              style: style.copyWith(color: colors.primary),
            ),
          ),
          Expanded(
            child: Text(
              entry.message,
              style: entry.level == LogLevel.error
                  ? style.copyWith(color: colors.error)
                  : style,
            ),
          ),
        ],
      ),
    );
  }
}
