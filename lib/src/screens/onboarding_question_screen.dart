import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

import '../state/onboarding_state.dart';

class OnboardingQuestionScreen extends ConsumerStatefulWidget {
  const OnboardingQuestionScreen({super.key});

  @override
  ConsumerState<OnboardingQuestionScreen> createState() =>
      _OnboardingQuestionScreenState();
}

class _OnboardingQuestionScreenState
    extends ConsumerState<OnboardingQuestionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  static const int maxChars = 600;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _recordTimer;
  DateTime? _recordStartAt;
  int _recordElapsedSeconds = 0;
  bool _recordedPlayMode = false; // after save, tick -> play toggle
  AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _positionSub;
  bool _isPlaying = false;
  int _playElapsedSeconds = 0;
  // Smooth timer using Duration for UI formatting
  Duration _playPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _saving = false;
  bool _audioIconGlowing = false;
  bool _videoIconGlowing = false;
  double _currentAmplitude = 0.0;
  late AnimationController _nextButtonController;

  @override
  void initState() {
    super.initState();
    _nextButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: .6,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _controller.dispose();
    _recorder.dispose();
    _nextButtonController.dispose();
    _positionSub?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await Permission.microphone.request().isGranted) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/onboarding_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    setState(() {
      _audioIconGlowing = true;
      _videoIconGlowing =
          false; // Ensure video doesn't glow when audio is clicked
      _recordedPlayMode = false;
      _recordElapsedSeconds = 0;
      _recordStartAt = DateTime.now();
    });
    ref.read(onboardingAnswerProvider.notifier).setRecording(true);

    // Subscribe to amplitude stream for responsive waveform
    _amplitudeSubscription =
        _recorder.onAmplitudeChanged(const Duration(milliseconds: 50)).listen(
      (amplitude) {
        if (mounted) {
          setState(() {
            // Normalize amplitude: typical range is -160 to 0 dB
            // Convert to 0-1 range with better sensitivity
            // Use exponential scaling for better visual response
            double normalized =
                (amplitude.current + 60) / 60; // -60 to 0 dB range
            normalized = normalized.clamp(0.0, 1.0);
            // Apply exponential curve for better visual response
            _currentAmplitude =
                normalized * normalized; // Square for exponential feel
          });
        }
      },
    );
    // Start live timer
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_recordStartAt != null) {
        setState(() {
          _recordElapsedSeconds =
              DateTime.now().difference(_recordStartAt!).inSeconds;
        });
      }
    });
  }

  Future<void> _stopRecording({bool save = true}) async {
    final path = await _recorder.stop();
    _amplitudeSubscription?.cancel();
    _recordTimer?.cancel();
    _recordTimer = null;
    setState(() {
      _audioIconGlowing = false;
      _currentAmplitude = 0.0;
    });
    ref.read(onboardingAnswerProvider.notifier).setRecording(false);
    if (!save) return;
    if (path != null) {
      ref.read(onboardingAnswerProvider.notifier).setAudio(path);
    }
  }

  void _handleAudioClick() {
    // Toggle recording: if recording, stop; if not recording and video not active, start
    if (_audioIconGlowing) {
      // Currently recording, stop and save
      _stopRecording(save: true);
    } else if (!_videoIconGlowing) {
      // Not recording and video not active, start recording
      _startRecording();
    }
  }

  void _toggleRecordedPlayMode() {
    // If not in play mode (tick state) → switch to play mode without auto-playing
    if (!_recordedPlayMode) {
      _enterPlayMode();
      return;
    }
    // In play mode: toggle pause/play
    _togglePlayPause();
  }

  Future<void> _enterPlayMode() async {
    final path = ref.read(onboardingAnswerProvider).audioPath;
    if (path == null) return;
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setFilePath(path);
      await _audioPlayer!.setLoopMode(LoopMode.off);
      setState(() {
        _recordedPlayMode = true;
        _isPlaying = false; // show play icon initially
        _playElapsedSeconds = 0;
        _playPosition = Duration.zero;
      });
      _positionSub?.cancel();
      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() {
          _playElapsedSeconds = pos.inSeconds;
          _playPosition = pos;
          // Guard: if we reached (or passed) duration, flip to play icon
          if (_audioDuration != Duration.zero &&
              pos >= _audioDuration - const Duration(milliseconds: 150)) {
            _isPlaying = false;
          }
        });
      });
      _audioPlayer!.durationStream.listen((dur) {
        if (!mounted) return;
        if (dur != null) {
          setState(() {
            _audioDuration = dur;
          });
        }
      });
    } catch (_) {
      // ignore
    }
  }

  void _deleteRecordedAudio() {
    ref.read(onboardingAnswerProvider.notifier).setAudio(null);
    setState(() {
      _recordedPlayMode = false;
      _isPlaying = false;
      _playElapsedSeconds = 0;
    });
    _positionSub?.cancel();
    _audioPlayer?.stop();
  }

  void _resetAllQuestion() {
    // Stop recording if active
    try {
      _recorder.stop();
    } catch (_) {}
    _amplitudeSubscription?.cancel();
    _recordTimer?.cancel();
    _recordTimer = null;
    // Stop playback if active
    try {
      _audioPlayer?.stop();
    } catch (_) {}
    _positionSub?.cancel();
    // Clear provider state
    final answerNotifier = ref.read(onboardingAnswerProvider.notifier);
    answerNotifier.setRecording(false);
    answerNotifier.setAudio(null);
    answerNotifier.setVideo(null);
    answerNotifier.setText('');
    // Clear UI state
    // Dismiss keyboard and remove focus to reset focused border
    FocusScope.of(context).unfocus();
    setState(() {
      _controller.text = '';
      _saving = false;
      _audioIconGlowing = false;
      _videoIconGlowing = false;
      _recordedPlayMode = false;
      _isPlaying = false;
      _recordStartAt = null;
      _recordElapsedSeconds = 0;
      _playElapsedSeconds = 0;
      _playPosition = Duration.zero;
      _audioDuration = Duration.zero;
      _currentAmplitude = 0.0;
    });
  }

  String _formatMMSS(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer == null) return;
    if (_isPlaying) {
      // Update UI immediately, then perform action
      setState(() {
        _isPlaying = false;
      });
      await _audioPlayer!.pause();
    } else {
      // If playback previously completed, start from beginning
      final dur = await _audioPlayer!.duration;
      if (dur != null && _playElapsedSeconds >= dur.inSeconds) {
        await _audioPlayer!.seek(Duration.zero);
      }
      // Update UI immediately, then perform action
      setState(() {
        _isPlaying = true;
      });
      await _audioPlayer!.play();
    }
  }

  void _handleVideoClick() {
    // Only allow if neither is currently active
    if (!_audioIconGlowing && !_videoIconGlowing) {
      _pickVideo();
    }
  }

  Future<void> _pickVideo() async {
    if (!await Permission.camera.request().isGranted) return;
    setState(() {
      _videoIconGlowing = true;
      _audioIconGlowing =
          false; // Ensure audio doesn't glow when video is clicked
    });
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) {
      setState(() {
        _videoIconGlowing = false;
      });
      return;
    }
    ref.read(onboardingAnswerProvider.notifier).setVideo(file.path);
    if (mounted) {
      setState(() {
        _videoIconGlowing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answer = ref.watch(onboardingAnswerProvider);
    final notifier = ref.read(onboardingAnswerProvider.notifier);
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardVisible = keyboardInset > 0;

    // Animate next width when record buttons hide
    // Hide the entire box if audio or video is recorded
    final bool hideAudio = answer.audioPath != null;
    final bool hideVideo = answer.videoPath != null;
    final bool hideBox =
        hideAudio || hideVideo; // Hide box if either is recorded
    _nextButtonController.animateTo(hideBox ? 1 : .6, curve: Curves.easeOut);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: AppBar(
            backgroundColor: const Color(0x05FFFFFF),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: SvgPicture.asset(
              'assets/appbarline2.svg',
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _resetAllQuestion,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: keyboardVisible ? 24 : 140,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Why do you want to host with us?',
                  style: theme.textTheme.displayLarge,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tell us about your intent and what motivates you to create experiences.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: Column(
                    children: [
                      // Text input
                      TextField(
                        controller: _controller,
                        maxLength: maxChars,
                        // Extend text field height based on whether media widgets take space
                        minLines: (answer.audioPath != null ||
                                answer.videoPath != null ||
                                answer.isRecordingAudio)
                            ? 6
                            : 10,
                        maxLines: (answer.audioPath != null ||
                                answer.videoPath != null ||
                                answer.isRecordingAudio)
                            ? 6
                            : 10,
                        onChanged: notifier.setText,
                        decoration: InputDecoration(
                          hintText: '/ Start typing here',
                          hintStyle: const TextStyle(
                            color: Color(0x29FFFFFF),
                          ),
                          counterText: '',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(.12),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_controller.text.characters.length}/$maxChars',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(.48),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Audio widget slot
                      if (answer.isRecordingAudio)
                        _RecordingWave(
                          amplitude: _currentAmplitude,
                          elapsedText: _formatMMSS(_recordElapsedSeconds),
                          onCancel: () => _stopRecording(save: false),
                        ),
                      if (!answer.isRecordingAudio && answer.audioPath != null)
                        _RecordedAudioBox(
                          // show live playback time in play mode, else recorded duration
                          elapsedText: _formatMMSS(
                            _recordedPlayMode
                                ? (_playPosition.inMilliseconds / 1000).floor()
                                : _recordElapsedSeconds,
                          ),
                          isPlayMode: _recordedPlayMode,
                          isPlaying: _isPlaying,
                          progress: (_recordedPlayMode &&
                                  _audioDuration != Duration.zero)
                              ? (_playPosition.inMilliseconds /
                                  _audioDuration.inMilliseconds)
                              : null,
                          onToggleLeftAction: _toggleRecordedPlayMode,
                          onDelete: _deleteRecordedAudio,
                        ),
                      // Video widget slot
                      if (answer.videoPath != null)
                        _VideoRecordedTile(
                          path: answer.videoPath!,
                          onDelete: () => notifier.setVideo(null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!hideBox)
                    _CombinedIconButtonBox(
                      showAudio: !hideAudio,
                      showVideo: !hideVideo,
                      audioGlowing: _audioIconGlowing,
                      videoGlowing: _videoIconGlowing,
                      onAudioPressed: _handleAudioClick,
                      onVideoPressed: _handleVideoClick,
                    ),
                  if (!hideBox) const SizedBox(width: 12),
                  Expanded(
                    child: SizeTransition(
                      sizeFactor: _nextButtonController,
                      axis: Axis.horizontal,
                      axisAlignment: -1,
                      child: _NextButton(
                        hasContent: answer.text.isNotEmpty ||
                            answer.audioPath != null ||
                            answer.videoPath != null,
                        saving: _saving,
                        onPressed: () async {
                          setState(() => _saving = true);
                          // ignore: avoid_print
                          print(
                            'Answer text: ${answer.text}, audio: ${answer.audioPath}, video: ${answer.videoPath}',
                          );
                          await Future<void>.delayed(
                            const Duration(milliseconds: 400),
                          );
                          if (mounted) setState(() => _saving = false);
                          if (mounted) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingWave extends ConsumerWidget {
  final double amplitude;
  final String elapsedText;
  final VoidCallback onCancel;
  const _RecordingWave({
    required this.amplitude,
    required this.elapsedText,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.12)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.32),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Audio Recording...',
                      style: theme.textTheme.titleMedium),
                ],
              ),
              IconButton(onPressed: onCancel, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mic circle to the left of the waveform during recording
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              // Waveform expands to fill, fixed height to fit nicely
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: _SimpleWaveform(amplitude: amplitude, height: 40),
                ),
              ),
              const SizedBox(width: 8),
              // Live timer on the right
              Text(
                elapsedText,
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordedAudioBox extends StatelessWidget {
  final String elapsedText;
  final bool isPlayMode;
  final bool isPlaying;
  final double? progress; // 0..1 of playback
  final VoidCallback onToggleLeftAction;
  final VoidCallback onDelete;
  const _RecordedAudioBox({
    required this.elapsedText,
    required this.isPlayMode,
    required this.isPlaying,
    required this.progress,
    required this.onToggleLeftAction,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPlayMode) ...[
                    Text(
                      'Audio Recorded',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      elapsedText,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Audio Recording...',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: onToggleLeftAction,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    // tick in confirm mode; in play mode show play/pause
                    isPlayMode
                        ? (isPlaying ? Icons.pause : Icons.play_arrow)
                        : Icons.check,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: _SimpleWaveform(
                    amplitude: 0.4,
                    height: 40,
                    playing: isPlayMode && isPlaying,
                    progress: progress,
                    rightToLeft: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (!isPlayMode)
                Text(
                  elapsedText,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (!isPlayMode) const SizedBox(height: 4),
          // Entire row can also toggle play if desired:
          // GestureDetector can be added around the row if needed in future
        ],
      ),
    );
  }
}

class _SimpleWaveform extends StatefulWidget {
  final double amplitude;
  final double height;
  final bool playing;
  final double? progress; // 0..1 if provided
  final bool rightToLeft;
  const _SimpleWaveform({
    required this.amplitude,
    this.height = 54,
    this.playing = false,
    this.progress,
    this.rightToLeft = false,
  });

  @override
  State<_SimpleWaveform> createState() => _SimpleWaveformState();
}

class _SimpleWaveformState extends State<_SimpleWaveform> {
  final math.Random _rnd = math.Random();
  final List<double> _bars = List<double>.filled(42, 0.1);
  Timer? _timer;
  double _phase = 0.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        setState(() {
          if (widget.playing && widget.progress == null) {
            _phase += 0.15;
          }
          _updateBars();
        });
      }
    });
  }

  void _updateBars() {
    final amplitudeValue = widget.amplitude.clamp(0.0, 1.0);

    // Base height directly from amplitude (minimum 0.15 for visibility)
    final baseHeight = 0.15 + (amplitudeValue * 0.85);

    for (var i = 0; i < _bars.length; i++) {
      // Natural variation; when playing, add scrolling phase
      final basePhase = (i * 0.3) + (_rnd.nextDouble() * 0.5);
      double scrollPhase = 0.0;
      if (widget.playing) {
        if (widget.progress != null) {
          // progress maps to full cycle; negative for right-to-left
          final dir = widget.rightToLeft ? -1.0 : 1.0;
          scrollPhase = dir * (widget.progress!.clamp(0.0, 1.0) * math.pi * 2);
        } else {
          scrollPhase = _phase;
        }
      }
      final phase = basePhase + scrollPhase;
      final waveVariation = (math.sin(phase) + 1) / 2;

      // Combine base height with wave variation
      // Higher amplitude = higher variation range
      final variationRange = amplitudeValue * 0.4;
      final barHeight = baseHeight + (waveVariation - 0.5) * variationRange;

      _bars[i] = barHeight.clamp(0.15, 1.0);
    }
  }

  @override
  void didUpdateWidget(_SimpleWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update bars immediately when amplitude changes
    if ((widget.amplitude - oldWidget.amplitude).abs() > 0.01) {
      _updateBars();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_bars.length, (i) {
          final v = _bars[i];
          // Color gradient grey→white sweep synchronized with progress if provided
          double sweepOffset;
          if (widget.playing) {
            if (widget.progress != null) {
              final dir = widget.rightToLeft ? -1.0 : 1.0;
              sweepOffset = dir * widget.progress!.clamp(0.0, 1.0);
            } else {
              sweepOffset = _phase * 0.05;
            }
          } else {
            sweepOffset = 0.0;
          }
          double t = ((i / _bars.length) + sweepOffset) % 1.0;
          if (t < 0) t += 1.0;
          final color = Color.lerp(Colors.grey.shade500, Colors.white, t)!;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                height: 12 + v * 42,
                decoration: BoxDecoration(
                  color: widget.playing ? color : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Removed legacy _AudioRecordedTile (replaced by _RecordedAudioBox)

class _VideoRecordedTile extends StatefulWidget {
  final String path;
  final VoidCallback onDelete;
  const _VideoRecordedTile({required this.path, required this.onDelete});

  @override
  State<_VideoRecordedTile> createState() => _VideoRecordedTileState();
}

class _VideoRecordedTileState extends State<_VideoRecordedTile> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      })
      ..addListener(() {
        final c = _controller;
        if (!mounted || c == null) return;
        if (c.value.isInitialized) {
          // If playback finished, pause and reset icon
          if (_isPlaying &&
              !c.value.isPlaying &&
              c.value.position >= c.value.duration) {
            setState(() {
              _isPlaying = false;
            });
          }
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final duration = _controller?.value.isInitialized == true
        ? _controller!.value.duration
        : Duration.zero;
    String format(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          // Left: small square thumbnail with play/pause overlay
          GestureDetector(
            onTap: () async {
              final c = _controller;
              if (c == null || !c.value.isInitialized) return;
              if (_isPlaying) {
                await c.pause();
                setState(() {
                  _isPlaying = false;
                });
              } else {
                await c.play();
                setState(() {
                  _isPlaying = true;
                });
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (_controller?.value.isInitialized == true)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    else
                      Container(color: Colors.black26),
                    Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Center: "Video Recorded • 00:47" centered
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Video Recorded'),
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  format(duration),
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Right: Delete
          IconButton(
            onPressed: widget.onDelete,
            icon: Icon(Icons.delete_outline, color: primary),
          ),
        ],
      ),
    );
  }
}

class _CombinedIconButtonBox extends StatelessWidget {
  final bool showAudio;
  final bool showVideo;
  final bool audioGlowing;
  final bool videoGlowing;
  final VoidCallback onAudioPressed;
  final VoidCallback onVideoPressed;

  const _CombinedIconButtonBox({
    required this.showAudio,
    required this.showVideo,
    this.audioGlowing = false,
    this.videoGlowing = false,
    required this.onAudioPressed,
    required this.onVideoPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showAudio)
              Expanded(
                child: InkWell(
                  onTap: onAudioPressed,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: audioGlowing
                        ? BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                            gradient: RadialGradient(
                              center: const Alignment(0.0, 0.0804),
                              radius: 0.9196,
                              colors: [
                                const Color(0xFF222222).withOpacity(0.4),
                                const Color(0xFF999999).withOpacity(0.4),
                                const Color(0xFF222222).withOpacity(0.4),
                              ],
                              stops: const [0.0, 0.4987, 1.0],
                            ),
                          )
                        : null,
                    child: SvgPicture.asset(
                      'assets/Audio.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
            if (showAudio && showVideo)
              Container(
                width: 1,
                height: 56,
                alignment: Alignment.center,
                child: Container(
                  width: 1,
                  height: 25,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            if (showVideo)
              Expanded(
                child: InkWell(
                  onTap: onVideoPressed,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: videoGlowing
                        ? BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            gradient: RadialGradient(
                              center: const Alignment(0.0, 0.0804),
                              radius: 0.9196,
                              colors: [
                                const Color(0xFF222222).withOpacity(0.4),
                                const Color(0xFF999999).withOpacity(0.4),
                                const Color(0xFF222222).withOpacity(0.4),
                              ],
                              stops: const [0.0, 0.4987, 1.0],
                            ),
                          )
                        : null,
                    child: SvgPicture.asset(
                      'assets/Video.svg',
                      width: 16,
                      height: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool hasContent;
  final bool saving;
  final VoidCallback onPressed;

  const _NextButton({
    required this.hasContent,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = hasContent ? 1.0 : 0.3;

    return SizedBox(
      width: 358,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.0804),
                  radius: 2.9553,
                  colors: [
                    const Color(0xFF222222).withOpacity(0.4),
                    const Color(0xFF999999).withOpacity(0.4),
                    const Color(0xFF222222).withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.4987, 1.0],
                ),
                border: Border.all(
                  width: 1,
                  color: Colors.transparent,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    width: 1,
                    color: Colors.transparent,
                  ),
                ),
                child: Stack(
                  children: [
                    // Gradient border using a workaround
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: const Alignment(-0.7, -0.7),
                            end: const Alignment(0.7, 0.7),
                            colors: [
                              const Color(0xFF101010).withOpacity(0.5),
                              const Color(0xFFFFFFFF).withOpacity(0.5),
                            ],
                            stops: const [0.0676, 0.9407],
                          ),
                        ),
                      ),
                    ),
                    // Inner container to create border effect
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: RadialGradient(
                              center: const Alignment(0.0, 0.0804),
                              radius: 2.9553,
                              colors: [
                                const Color(0xFF222222).withOpacity(0.4),
                                const Color(0xFF999999).withOpacity(0.4),
                                const Color(0xFF222222).withOpacity(0.4),
                              ],
                              stops: const [0.0, 0.4987, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Button content
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: hasContent && !saving ? onPressed : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                saving ? 'Saving...' : 'Next',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.2,
                                ),
                              ),
                              if (!saving) ...[
                                const SizedBox(width: 8),
                                Align(
                                  alignment: Alignment.center,
                                  child: SvgPicture.asset(
                                    'assets/NextArrow.svg',
                                    height: 16,
                                    width: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
