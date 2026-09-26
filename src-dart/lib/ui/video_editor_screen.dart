import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../domain/interval_model.dart';
import '../services/app_controller.dart';
import '../services/playback_controller.dart';
import 'annotation_table.dart';
import 'interval_slider.dart';

final class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({
    required this.controller,
    required this.videoPath,
    super.key,
  });

  final AppController controller;
  final String videoPath;

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

final class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final MediaKitPlaybackBackend backend;
  late final MediaKitPlaybackController playback;

  @override
  void initState() {
    super.initState();
    final video = widget.controller.database.findVideo(widget.videoPath)!;
    final annotation = video.annotation!;
    backend = MediaKitPlaybackBackend();
    playback = MediaKitPlaybackController(
      backend: backend,
      onSelectedChanged: (index) =>
          widget.controller.setLastInterval(widget.videoPath, index),
    );
    unawaited(
      playback.open(
        video.path,
        durationMs: video.durationMs,
        intervalMs: annotation.intervalMs,
        startIndex: annotation.lastInterval,
      ),
    );
  }

  @override
  void dispose() {
    playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.controller.database.findVideo(widget.videoPath)!;
    final annotation = video.annotation!;
    final template = widget.controller.database.findTemplate(
      annotation.templateId,
    )!;
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(video.path))),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[playback, widget.controller]),
        builder: (context, _) => Column(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: ColoredBox(
                        color: Colors.black,
                        child: ValueListenableBuilder<VideoController?>(
                          valueListenable: backend.videoController,
                          builder: (context, output, _) => output == null
                              ? const Center(child: CircularProgressIndicator())
                              : Video(
                                  controller: output,
                                  controls: NoVideoControls,
                                ),
                        ),
                      ),
                    ),
                    if (playback.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          playback.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    IntervalSlider(
                      durationMs: video.durationMs,
                      intervalMs: annotation.intervalMs,
                      positionMs: playback.positionMs,
                      onChanged: (value) =>
                          unawaited(playback.scrubTo(value.round())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Previous interval',
                          onPressed: playback.selected == 0
                              ? null
                              : () => unawaited(
                                  playback.goTo(playback.selected - 1),
                                ),
                          icon: const Icon(Icons.skip_previous),
                        ),
                        IconButton.filled(
                          tooltip: playback.isPlaying ? 'Pause' : 'Play',
                          onPressed: () => unawaited(
                            playback.isPlaying
                                ? playback.pause()
                                : playback.play(),
                          ),
                          icon: Icon(
                            playback.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Replay interval',
                          onPressed: () => unawaited(playback.replay()),
                          icon: const Icon(Icons.replay),
                        ),
                        IconButton(
                          tooltip: 'Next interval',
                          onPressed:
                              playback.selected + 1 >= playback.intervalCount
                              ? null
                              : () => unawaited(
                                  playback.goTo(playback.selected + 1),
                                ),
                          icon: const Icon(Icons.skip_next),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_seconds(playback.positionMs)} / ${_seconds(video.durationMs)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Text(
                    'Interval ${playback.selected + 1} of ${playback.intervalCount}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${_seconds(IntervalModel.startMs(playback.selected, annotation.intervalMs))}'
                    '–${_seconds(IntervalModel.endMs(playback.selected, video.durationMs, annotation.intervalMs))}',
                  ),
                  const SizedBox(height: 20),
                  AnnotationTable(
                    key: ValueKey<int>(playback.selected),
                    template: template,
                    interval: annotation.intervals[playback.selected],
                    onChanged: (attributeId, valueId) =>
                        widget.controller.setIntervalValue(
                          video.path,
                          playback.selected,
                          attributeId,
                          valueId,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _seconds(int milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(3)} s';
}
