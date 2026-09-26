import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../domain/models.dart';
import '../services/app_controller.dart';
import 'video_editor_screen.dart';

final class VideosScreen extends StatelessWidget {
  const VideosScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Videos',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    controller.database.videosFolder.isEmpty
                        ? 'Choose a folder containing MP4, AVI, or WebM files.'
                        : controller.database.videosFolder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: controller.scanning
                  ? null
                  : () async {
                      final directory = await getDirectoryPath(
                        initialDirectory:
                            controller.database.videosFolder.isEmpty
                            ? null
                            : controller.database.videosFolder,
                      );
                      if (directory != null) {
                        await controller.scanFolder(directory);
                      }
                    },
              icon: const Icon(Icons.folder_open),
              label: Text(controller.scanning ? 'Scanning…' : 'Choose folder'),
            ),
          ],
        ),
        if (controller.scanning) ...<Widget>[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: controller.scanTotal == 0
                ? null
                : controller.scanCompleted / controller.scanTotal,
          ),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: controller.database.videos.isEmpty
              ? const Center(child: Text('No videos discovered yet.'))
              : ListView.separated(
                  itemCount: controller.database.videos.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _VideoRow(
                    controller: controller,
                    video: controller.database.videos[index],
                  ),
                ),
        ),
      ],
    ),
  );
}

final class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.controller, required this.video});

  final AppController controller;
  final VideoRecord video;

  @override
  Widget build(BuildContext context) {
    final annotation = video.annotation;
    final template = annotation == null
        ? null
        : controller.database.findTemplate(annotation.templateId);
    final intervalChanged =
        template != null && template.intervalMs != annotation!.intervalMs;
    return ListTile(
      enabled: !video.missing,
      leading: Icon(video.missing ? Icons.link_off : Icons.movie_outlined),
      title: Text(p.basename(video.path)),
      subtitle: Text(
        <String>[
          if (video.missing) 'Missing',
          if (video.durationMs > 0) _formatDuration(video.durationMs),
          if (template != null) template.name,
          if (intervalChanged) 'Uses previous interval length',
        ].join(' • '),
      ),
      trailing: SizedBox(
        width: 310,
        child: Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: annotation?.templateId,
                decoration: const InputDecoration(
                  labelText: 'Template',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...controller.database.templates.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: video.missing
                    ? null
                    : (templateId) => _changeTemplate(context, templateId),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: annotation == null || video.missing
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => VideoEditorScreen(
                          controller: controller,
                          videoPath: video.path,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.edit),
              label: const Text('Annotate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeTemplate(BuildContext context, String? templateId) async {
    if (templateId == video.annotation?.templateId) return;
    if (controller.videoHasAnnotations(video.path)) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Clear existing annotations?'),
              content: const Text(
                'Changing or removing the template permanently clears this '
                "video's interval annotations.",
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Clear and continue'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }
    if (templateId == null) {
      controller.clearTemplate(video.path);
    } else {
      final error = controller.applyTemplate(video.path, templateId);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  static String _formatDuration(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
