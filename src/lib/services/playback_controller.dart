import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/interval_model.dart';
import '../localization/app_strings.dart';
import 'app_log.dart';

abstract interface class PlaybackBackend {
  Stream<int> get positionChanges;
  Stream<bool> get playingChanges;
  Stream<bool> get completedChanges;
  Stream<String> get errors;
  int get positionMs;
  bool get isPlaying;
  Future<void> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(int positionMs);
  Future<void> useSoftwareDecoding(String path, int positionMs);
  Future<void> dispose();
}

abstract interface class PlaybackController {
  int get selected;
  int get intervalCount;
  int get positionMs;
  bool get isPlaying;
  bool get selectedCompleted;
  String? get error;
  Future<void> open(
    String path, {
    required int durationMs,
    required int intervalMs,
    required int startIndex,
  });
  Future<void> goTo(int index);
  Future<void> scrubTo(int requestedMs);
  Future<void> play();
  Future<void> pause();
  Future<void> replay();
  void dispose();
}

final class MediaKitPlaybackBackend implements PlaybackBackend {
  MediaKitPlaybackBackend() {
    _createPlayer(hardware: true);
  }

  final positionOutput = StreamController<int>.broadcast();
  final playingOutput = StreamController<bool>.broadcast();
  final completedOutput = StreamController<bool>.broadcast();
  final errorOutput = StreamController<String>.broadcast();
  final videoController = ValueNotifier<VideoController?>(null);
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _log = AppLog.instance;
  late Player _player;

  void _createPlayer({required bool hardware}) {
    // mpv only forwards errors by default; its warnings (devices, codecs,
    // A/V sync) are worth having in the diagnostics log too.
    final player = _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _log.info(
      'reprodução',
      'Leitor criado (aceleração por hardware: ${hardware ? 'sim' : 'não'})',
    );
    videoController.value = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: hardware,
        hwdec: hardware ? 'auto-safe' : 'no',
      ),
    );
    _subscriptions
      ..add(
        player.stream.position.listen(
          (value) => positionOutput.add(value.inMilliseconds),
        ),
      )
      ..add(player.stream.playing.listen(playingOutput.add))
      ..add(player.stream.completed.listen(completedOutput.add))
      ..add(player.stream.error.listen(errorOutput.add))
      ..add(player.stream.log.listen(_logMpv))
      ..add(
        player.stream.videoParams
            .where((params) => params.w != null)
            .distinct((left, right) => left.w == right.w && left.h == right.h)
            .listen(
              (params) => _log.info(
                'reprodução',
                'Vídeo ${params.w}x${params.h} (${params.pixelformat})',
              ),
            ),
      );
    final native = player.platform;
    if (native is NativePlayer) {
      unawaited(_observe(native, 'video-codec', 'Codec de vídeo'));
      unawaited(
        _observe(native, 'hwdec-current', 'Descodificação por hardware'),
      );
      unawaited(_observe(native, 'current-ao', 'Saída de áudio'));
    }
  }

  // media_kit sets the Lua-only 'osc' option, asks for a disk cache without a
  // cache directory and opens files through a playlist. mpv complains about
  // each on every file even though playback is unaffected.
  static const _expectedMpvMessages = <String>[
    '_setProperty(osc,',
    'Failed to create file cache.',
    'Reading plaintext playlist.',
  ];

  void _logMpv(PlayerLog entry) {
    final message = '[${entry.prefix}] ${entry.text}';
    if (_expectedMpvMessages.any(entry.text.contains)) {
      _log.info('mpv', message);
      return;
    }
    switch (entry.level) {
      case 'fatal' || 'error':
        _log.error('mpv', message);
      case 'warn':
        _log.warning('mpv', message);
      default:
        _log.info('mpv', message);
    }
  }

  Future<void> _observe(
    NativePlayer player,
    String property,
    String label,
  ) async {
    String? last;
    try {
      await player.observeProperty(property, (value) async {
        if (value == last) return;
        last = value;
        _log.info('reprodução', '$label: $value');
      });
    } on Object {
      // The player was disposed before it finished initializing.
    }
  }

  @override
  Stream<int> get positionChanges => positionOutput.stream;
  @override
  Stream<bool> get playingChanges => playingOutput.stream;
  @override
  Stream<bool> get completedChanges => completedOutput.stream;
  @override
  Stream<String> get errors => errorOutput.stream;
  @override
  int get positionMs => _player.state.position.inMilliseconds;
  @override
  bool get isPlaying => _player.state.playing;

  @override
  Future<void> open(String path) {
    _log.info('reprodução', 'A abrir $path');
    return _player.open(Media(File(path).uri.toString()), play: false);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(int positionMs) =>
      _player.seek(Duration(milliseconds: positionMs));

  @override
  Future<void> useSoftwareDecoding(String path, int positionMs) async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    _createPlayer(hardware: false);
    await open(path);
    await seek(positionMs);
    await pause();
  }

  Future<Uint8List?> screenshot() => _player.screenshot(format: 'image/png');

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    _log.info('reprodução', 'Leitor fechado');
    videoController.dispose();
    await positionOutput.close();
    await playingOutput.close();
    await completedOutput.close();
    await errorOutput.close();
  }
}

final class MediaKitPlaybackController extends ChangeNotifier
    implements PlaybackController {
  MediaKitPlaybackController({
    required this.strings,
    PlaybackBackend? backend,
    this.onSelectedChanged,
    this.onIntervalCompleted,
  }) : backend = backend ?? MediaKitPlaybackBackend() {
    _subscriptions
      ..add(this.backend.positionChanges.listen(_handlePosition))
      ..add(this.backend.playingChanges.listen((_) => notifyListeners()))
      ..add(
        this.backend.completedChanges.listen((completed) {
          if (completed) _completeSelected();
        }),
      )
      ..add(this.backend.errors.listen(_handleError));
  }

  final PlaybackBackend backend;
  final _log = AppLog.instance;
  final AppStrings strings;
  final ValueChanged<int>? onSelectedChanged;
  final ValueChanged<int>? onIntervalCompleted;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _pollTimer;
  Stopwatch? _seekClock;
  String? _path;
  int _durationMs = 0;
  int _intervalMs = 1;
  int _intervalCount = 1;
  int _selected = 0;
  int _positionMs = 0;
  bool _selectedCompleted = false;
  int? _seekTargetMs;
  bool _softwareFallbackAttempted = false;
  String? _error;

  @override
  int get selected => _selected;
  @override
  int get intervalCount => _intervalCount;
  @override
  int get positionMs => _positionMs;
  @override
  bool get isPlaying => backend.isPlaying;
  @override
  bool get selectedCompleted => _selectedCompleted;
  @override
  String? get error => _error;

  int get durationMs => _durationMs;
  int get intervalMs => _intervalMs;

  @override
  Future<void> open(
    String path, {
    required int durationMs,
    required int intervalMs,
    required int startIndex,
  }) async {
    _path = path;
    _durationMs = durationMs;
    _intervalMs = intervalMs > 0 ? intervalMs : 1;
    _intervalCount = IntervalModel.intervalCount(durationMs, _intervalMs);
    _selected = IntervalModel.clampIndex(startIndex, _intervalCount);
    _selectedCompleted = false;
    _softwareFallbackAttempted = false;
    _error = null;
    await backend.open(path);
    await goTo(_selected);
  }

  @override
  Future<void> goTo(int index) async {
    _selected = IntervalModel.clampIndex(index, _intervalCount);
    _selectedCompleted = false;
    await _requestSeek(IntervalModel.startMs(_selected, _intervalMs));
    await backend.pause();
    onSelectedChanged?.call(_selected);
    notifyListeners();
  }

  @override
  Future<void> scrubTo(int requestedMs) async {
    _selected = IntervalModel.indexForScrub(
      requestedMs,
      _intervalMs,
      _intervalCount,
    );
    _selectedCompleted = false;
    await _requestSeek(requestedMs.clamp(0, _durationMs).toInt());
    await backend.pause();
    onSelectedChanged?.call(_selected);
    notifyListeners();
  }

  @override
  Future<void> play() async {
    if (_selectedCompleted) {
      if (_selected + 1 >= _intervalCount) return;
      _selected++;
      _selectedCompleted = false;
      onSelectedChanged?.call(_selected);
    }
    await backend.play();
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _handlePosition(backend.positionMs),
    );
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    await backend.pause();
    _pollTimer?.cancel();
    _pollTimer = null;
    notifyListeners();
  }

  @override
  Future<void> replay() async {
    _selectedCompleted = false;
    await _requestSeek(IntervalModel.startMs(_selected, _intervalMs));
    await play();
  }

  Future<void> _requestSeek(int targetMs) async {
    _seekTargetMs = targetMs;
    _seekClock = Stopwatch()..start();
    await backend.seek(targetMs);
  }

  void _handlePosition(int positionMs) {
    _positionMs = positionMs;
    final seekTarget = _seekTargetMs;
    if (seekTarget != null) {
      final settled = (positionMs - seekTarget).abs() <= 500;
      final timedOut = (_seekClock?.elapsedMilliseconds ?? 0) >= 1000;
      if (!settled && !timedOut) {
        notifyListeners();
        return;
      }
      _seekTargetMs = null;
      _seekClock = null;
    }
    if (backend.isPlaying &&
        IntervalModel.reachedEnd(
          positionMs,
          _selected,
          _durationMs,
          _intervalMs,
        )) {
      _completeSelected();
    }
    notifyListeners();
  }

  void _completeSelected() {
    if (_selectedCompleted) return;
    _selectedCompleted = true;
    unawaited(pause());
    onIntervalCompleted?.call(_selected);
    notifyListeners();
  }

  void _handleError(String message) {
    // mpv keeps playing the video without sound when no audio output opens;
    // software decoding cannot fix that, so report it without the fallback.
    if (message.startsWith('Could not open/initialize audio device')) {
      _log.warning('reprodução', 'Sem dispositivo de áudio: $message');
      _error = strings.text('error_audio_device');
      notifyListeners();
      return;
    }
    _log.error('reprodução', 'Erro de reprodução: $message');
    final path = _path;
    if (!_softwareFallbackAttempted && path != null) {
      _softwareFallbackAttempted = true;
      _log.warning('reprodução', 'A tentar a descodificação por software');
      unawaited(() async {
        try {
          await backend.useSoftwareDecoding(path, _positionMs);
          _error = strings.text('error_hardware_decoding');
        } on Object catch (fallbackError, stackTrace) {
          _log.error(
            'reprodução',
            'Falha da descodificação por software',
            fallbackError,
            stackTrace,
          );
          _error = strings.text('error_software_decoding');
        }
        notifyListeners();
      }());
      return;
    }
    _error = strings.text('error_playback');
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(backend.dispose());
    super.dispose();
  }
}
