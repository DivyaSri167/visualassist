import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../../core/networking/mjpeg_stream_parser.dart';
import '../domain/camera_frame.dart';

/// State of the MJPEG stream engine.
enum StreamPlaybackStatus { idle, connecting, streaming, error, stopped }

/// Stream connection health indicator based on active FPS.
enum StreamHealth { good, fair, degraded, offline }

class StreamState {
  final StreamPlaybackStatus status;
  final CameraFrame? currentFrame;
  final double fps;
  final int totalFrames;
  final String? errorMessage;
  final String? troubleshootingGuide;
  final int retryAttempt;

  const StreamState({
    this.status = StreamPlaybackStatus.idle,
    this.currentFrame,
    this.fps = 0.0,
    this.totalFrames = 0,
    this.errorMessage,
    this.troubleshootingGuide,
    this.retryAttempt = 0,
  });

  bool get isStreaming => status == StreamPlaybackStatus.streaming;
  bool get isConnecting => status == StreamPlaybackStatus.connecting;

  StreamHealth get health {
    if (status != StreamPlaybackStatus.streaming) return StreamHealth.offline;
    if (fps >= 10.0) return StreamHealth.good;
    if (fps >= 4.0) return StreamHealth.fair;
    return StreamHealth.degraded;
  }

  StreamState copyWith({
    StreamPlaybackStatus? status,
    CameraFrame? currentFrame,
    double? fps,
    int? totalFrames,
    String? errorMessage,
    String? troubleshootingGuide,
    int? retryAttempt,
    bool clearError = false,
  }) {
    return StreamState(
      status: status ?? this.status,
      currentFrame: currentFrame ?? this.currentFrame,
      fps: fps ?? this.fps,
      totalFrames: totalFrames ?? this.totalFrames,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      troubleshootingGuide: clearError
          ? null
          : (troubleshootingGuide ?? this.troubleshootingGuide),
      retryAttempt: retryAttempt ?? this.retryAttempt,
    );
  }
}

/// Service managing the HTTP MJPEG stream lifecycle and frame delivery.
class CameraStreamService {
  http.Client? _client;
  StreamSubscription? _subscription;
  final _stateController = StreamController<StreamState>.broadcast();

  StreamState _currentState = const StreamState();
  StreamState get currentState => _currentState;
  Stream<StreamState> get stateStream => _stateController.stream;

  // FPS calculation variables
  final List<DateTime> _frameTimestamps = [];
  int _frameCounter = 0;

  // Auto-recovery parameters
  Uri? _activeStreamUri;
  int _retryCount = 0;
  static const int maxAutoRetries = 3;
  Timer? _reconnectTimer;
  bool _isManualStop = false;

  void _emit(StreamState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Starts the MJPEG stream from the specified URI.
  /// Prevents concurrent streaming sessions by terminating any prior session.
  Future<void> startStream(Uri streamUri) async {
    _isManualStop = false;
    _activeStreamUri = streamUri;

    // If already connecting or streaming, terminate cleanly first
    await _closeResources();

    _emit(
      _currentState.copyWith(
        status: StreamPlaybackStatus.connecting,
        clearError: true,
        fps: 0.0,
        retryAttempt: _retryCount,
      ),
    );

    _frameCounter = 0;
    _frameTimestamps.clear();

    final client = http.Client();
    _client = client;

    try {
      final request = http.Request('GET', streamUri);
      request.headers['Accept'] = 'multipart/x-mixed-replace';
      request.headers['Connection'] = 'keep-alive';

      final streamedResponse = await client
          .send(request)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw const ConnectionTimeoutException(
              'Timeout establishing video stream connection.',
            ),
          );

      if (streamedResponse.statusCode != 200) {
        throw StreamConnectionException(
          'ESP32-CAM stream endpoint returned HTTP ${streamedResponse.statusCode}.',
        );
      }

      final contentType = streamedResponse.headers['content-type'] ?? '';
      final boundary = MjpegStreamParser.extractBoundary(contentType);
      final parser = MjpegStreamParser(boundary: boundary);

      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.streaming,
          clearError: true,
          retryAttempt: 0,
        ),
      );

      _subscription = parser
          .parseStream(streamedResponse.stream)
          .listen(
            (frameBytes) {
              _handleNewFrame(frameBytes);
            },
            onError: (error) {
              _handleError(error);
            },
            onDone: () {
              if (!_isManualStop && _activeStreamUri != null) {
                _scheduleReconnect('Stream stream closed by host.');
              } else {
                _emit(
                  _currentState.copyWith(
                    status: StreamPlaybackStatus.stopped,
                    fps: 0.0,
                  ),
                );
              }
            },
            cancelOnError: true,
          );
    } on TimeoutException {
      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.error,
          errorMessage: 'Connection to stream timed out after 5 seconds.',
          troubleshootingGuide:
              'Verify phone is connected to "VisionAssist-Cap" Wi-Fi.',
        ),
      );
      await _closeResources();
    } on SocketException catch (e) {
      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.error,
          errorMessage: 'Network error connecting to stream: ${e.message}',
          troubleshootingGuide:
              'Check that the ESP32-CAM is powered and within Wi-Fi range.',
        ),
      );
      await _closeResources();
    } on AppException catch (e) {
      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.error,
          errorMessage: e.message,
          troubleshootingGuide: e.troubleshootingGuide,
        ),
      );
      await _closeResources();
    } catch (e) {
      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.error,
          errorMessage: 'Unable to start camera stream: $e',
          troubleshootingGuide: 'Ensure no other client is currently connected to the ESP32-CAM stream.',
        ),
      );
      await _closeResources();
    }
  }

  void _handleNewFrame(List<int> frameBytes) {
    final now = DateTime.now();
    _frameCounter++;

    // Reset retry counter after steady stream
    if (_retryCount > 0 && _frameCounter > 10) {
      _retryCount = 0;
    }

    // Calculate rolling FPS over the last 1 second
    _frameTimestamps.add(now);
    _frameTimestamps.removeWhere(
      (t) => now.difference(t).inMilliseconds > 1000,
    );
    final fps = _frameTimestamps.length.toDouble();

    final frame = CameraFrame(
      bytes: frameBytes is Uint8List
          ? frameBytes
          : Uint8List.fromList(frameBytes),
      timestamp: now,
      frameIndex: _frameCounter,
    );

    _emit(
      _currentState.copyWith(
        status: StreamPlaybackStatus.streaming,
        currentFrame: frame,
        fps: fps,
        totalFrames: _frameCounter,
      ),
    );
  }

  void _handleError(Object error) {
    if (_isManualStop) return;

    if (_retryCount < maxAutoRetries && _activeStreamUri != null) {
      _scheduleReconnect('Transient stream interruption: $error');
    } else {
      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.error,
          errorMessage: 'Stream connection lost: $error',
          troubleshootingGuide: 'The ESP32-CAM may have restarted or lost Wi-Fi signal. Tap "Reconnect" to retry.',
          fps: 0.0,
        ),
      );
      _closeResources();
    }
  }

  void _scheduleReconnect(String reason) {
    _retryCount++;
    _reconnectTimer?.cancel();
    _closeResources();

    _emit(
      _currentState.copyWith(
        status: StreamPlaybackStatus.connecting,
        errorMessage: 'Reconnecting to camera (attempt $_retryCount of $maxAutoRetries)...',
        retryAttempt: _retryCount,
      ),
    );

    _reconnectTimer = Timer(Duration(milliseconds: 800 * _retryCount), () {
      if (!_isManualStop && _activeStreamUri != null) {
        startStream(_activeStreamUri!);
      }
    });
  }

  Future<void> _closeResources() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      _client?.close();
    } catch (_) {}
    _client = null;
  }

  /// Terminates the video stream and frees network socket resources.
  Future<void> stopStream() async {
    _isManualStop = true;
    _retryCount = 0;
    _activeStreamUri = null;
    await _closeResources();

    if (_currentState.status == StreamPlaybackStatus.streaming ||
        _currentState.status == StreamPlaybackStatus.connecting) {
      _emit(
        _currentState.copyWith(
          status: StreamPlaybackStatus.stopped,
          fps: 0.0,
          retryAttempt: 0,
        ),
      );
    }
  }

  void dispose() {
    stopStream();
    _stateController.close();
  }
}
