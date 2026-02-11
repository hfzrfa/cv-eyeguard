import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/face_analyzer_service.dart';
import '../../core/services/drowsiness_detector_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/storage_service.dart';
import '../calibration/calibration_screen.dart';
import 'widgets/status_banner.dart';
import 'widgets/metrics_panel.dart';
import 'widgets/camera_preview_widget.dart';
import 'widgets/control_buttons.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isMonitoring = true;
  bool _showDebug = true;
  bool _useFrontCamera = true;

  late FaceAnalyzerService _faceAnalyzer;
  late DrowsinessDetectorService _drowsinessDetector;
  late TTSService _ttsService;
  late StorageService _storageService;

  DrowsinessState _currentState = DrowsinessState();
  FaceAnalysisResult? _lastFaceResult;

  // Rotation testing untuk mencari rotation yang benar
  int _currentRotationIndex = 0;
  int _failedDetections = 0;
  static const int _rotationTestThreshold = 30;
  final List<InputImageRotation> _rotationsToTry = [
    InputImageRotation.rotation0deg,
    InputImageRotation.rotation90deg,
    InputImageRotation.rotation180deg,
    InputImageRotation.rotation270deg,
  ];
  InputImageRotation? _workingRotation;

  // Session tracking
  DateTime? _sessionStart;
  int _totalFrames = 0;
  int _drowsyFrames = 0;
  int _distractedFrames = 0;
  int _alertCount = 0;
  double _earSum = 0;
  double _maxPerclos = 0;

  // FPS tracking
  int _frameCount = 0;
  double _fps = 0;
  DateTime? _fpsLastTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _faceAnalyzer = FaceAnalyzerService();
    _drowsinessDetector = DrowsinessDetectorService(
      onStateChanged: _onStateChanged,
      onAlert: _onAlert,
    );
    _ttsService = TTSService();
    _storageService = StorageService();

    await _faceAnalyzer.initialize();
    await _ttsService.initialize();
    await _storageService.initialize();

    // Load calibration data
    final calibration = await _storageService.loadCalibration();
    if (calibration.calibrated) {
      _drowsinessDetector.updateCalibration(calibration);
    }

    await _initializeCamera();

    _sessionStart = DateTime.now();
  }

  Future<void> _initializeCamera({bool retry = true}) async {
    // Ensure we don't hold onto an old controller/stream.
    await _disposeCamera();

    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required for monitoring'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
      return;
    }

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      return;
    }

    // Find front camera
    CameraDescription? selectedCamera;
    for (final camera in _cameras!) {
      if (_useFrontCamera &&
          camera.lensDirection == CameraLensDirection.front) {
        selectedCamera = camera;
        break;
      } else if (!_useFrontCamera &&
          camera.lensDirection == CameraLensDirection.back) {
        selectedCamera = camera;
        break;
      }
    }
    selectedCamera ??= _cameras!.first;

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();

      debugPrint('[Monitor] Camera initialized: '
          '${_cameraController!.value.previewSize}, '
          'sensor: ${selectedCamera.sensorOrientation}');

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      // Start image stream
      await _cameraController!.startImageStream(_processImage);
    } catch (e) {
      debugPrint('Camera initialization error: $e');

      // If we just returned from another camera screen, the plugin can still
      // be releasing resources. Retry once after a short delay.
      await _disposeCamera();
      if (retry && mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        await _initializeCamera(retry: false);
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;

    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Ignore: stream may already be stopped/disposed.
    }

    try {
      await controller.dispose();
    } catch (_) {
      // Ignore: controller may already be disposed.
    }
  }

  Future<void> _openCalibration() async {
    if (!mounted) return;

    final navigator = Navigator.of(context);

    // Navigating to calibration needs exclusive access to the camera.
    final wasMonitoring = _isMonitoring;
    setState(() {
      _isMonitoring = false;
      _isInitialized = false;
    });

    // Release camera so CalibrationScreen can initialize its own controller.
    await _disposeCamera();

    await navigator.push(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );

    if (!mounted) return;

    // Give the calibration screen a moment to fully release camera resources.
    await Future.delayed(const Duration(milliseconds: 250));

    // Reload calibration data in case it was updated.
    try {
      final calibration = await _storageService.loadCalibration();
      if (calibration.calibrated) {
        _drowsinessDetector.updateCalibration(calibration);
      }
    } catch (e) {
      debugPrint('[Monitor] Failed to reload calibration: $e');
    }

    _drowsinessDetector.reset();
    _failedDetections = 0;
    _workingRotation = null;
    _isProcessing = false;

    if (mounted) {
      setState(() {
        _isMonitoring = wasMonitoring;
      });
    }

    await _initializeCamera();
  }

  Future<void> _processImage(CameraImage image) async {
    if (!_isMonitoring || _isProcessing || !mounted) return;
    if (_cameraController == null) return;

    _isProcessing = true;
    _totalFrames++;

    // Calculate FPS
    _frameCount++;
    final now = DateTime.now();
    if (_fpsLastTime != null) {
      final diff = now.difference(_fpsLastTime!).inMilliseconds;
      if (diff >= 1000) {
        _fps = _frameCount * 1000 / diff;
        _frameCount = 0;
        _fpsLastTime = now;
      }
    } else {
      _fpsLastTime = now;
    }

    try {
      // Convert camera image to InputImage
      final controller = _cameraController;
      if (controller == null) return;

      final camera = controller.description;
      InputImage inputImage;

      // Gunakan rotation yang sudah ditemukan, atau coba yang default
      if (_workingRotation != null) {
        inputImage = image.toInputImageWithRotation(camera, _workingRotation!);
      } else {
        inputImage = image.toInputImage(camera);
      }

      // Analyze face
      final faceResult = await _faceAnalyzer.analyzeImage(inputImage);

      // Rotation testing jika banyak frame gagal
      if (!faceResult.faceDetected && _workingRotation == null) {
        _failedDetections++;

        if (_failedDetections >= _rotationTestThreshold) {
          _currentRotationIndex =
              (_currentRotationIndex + 1) % _rotationsToTry.length;
          _failedDetections = 0;

          debugPrint(
              '[Monitor] Testing rotation: ${_rotationsToTry[_currentRotationIndex]}');

          final testImage = image.toInputImageWithRotation(
            camera,
            _rotationsToTry[_currentRotationIndex],
          );
          final testResult = await _faceAnalyzer.analyzeImage(testImage);

          if (testResult.faceDetected) {
            _workingRotation = _rotationsToTry[_currentRotationIndex];
            debugPrint('[Monitor] ✅ Found working rotation: $_workingRotation');
            _lastFaceResult = testResult;
          }
        }
      } else if (faceResult.faceDetected) {
        if (_workingRotation == null) {
          _workingRotation = inputImage.metadata?.rotation;
          debugPrint(
              '[Monitor] ✅ Default rotation works! rotation=$_workingRotation');
        }
        _failedDetections = 0;
        _lastFaceResult = faceResult;
      }

      // Process drowsiness
      final state = _drowsinessDetector.processFrame(faceResult);

      // Track session stats
      if (state.ear > 0) {
        _earSum += state.ear;
      }
      if (state.perclos > _maxPerclos) {
        _maxPerclos = state.perclos;
      }
      if (state.status == DriverStatus.drowsy) {
        _drowsyFrames++;
      } else if (state.status == DriverStatus.distracted) {
        _distractedFrames++;
      }

      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    } catch (e) {
      debugPrint('Image processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _onStateChanged(DrowsinessState state) {
    // State already updated in _processImage
  }

  void _onAlert(AlertReason reason, String message) {
    _alertCount++;

    // TTS alert
    _ttsService.speakAlert(reason);

    // Vibration
    if (reason == AlertReason.eyesClosed ||
        reason == AlertReason.perclosHigh ||
        reason == AlertReason.headDown) {
      Vibration.vibrate(duration: 500, amplitude: 255);
    } else {
      Vibration.vibrate(duration: 200);
    }
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });

    if (!_isMonitoring) {
      _ttsService.speak('Monitoring paused', category: 'system');
    } else {
      _ttsService.speak('Monitoring resumed', category: 'system');
      _drowsinessDetector.reset();
    }
  }

  void _toggleDebug() {
    setState(() {
      _showDebug = !_showDebug;
    });
  }

  Future<void> _switchCamera() async {
    _useFrontCamera = !_useFrontCamera;

    await _disposeCamera();

    setState(() {
      _isInitialized = false;
    });

    await _initializeCamera();
  }

  Future<void> _saveSession() async {
    if (_sessionStart == null) return;

    final session = SessionData(
      startTime: _sessionStart!,
      endTime: DateTime.now(),
      totalFrames: _totalFrames,
      drowsyFrames: _drowsyFrames,
      distractedFrames: _distractedFrames,
      alertCount: _alertCount,
      averageEAR: _totalFrames > 0 ? _earSum / _totalFrames : 0,
      maxPerclos: _maxPerclos,
    );

    await _storageService.saveSession(session);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Release camera resources when app is backgrounded.
      _disposeCamera();
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveSession();
    _disposeCamera();
    _faceAnalyzer.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Status Banner
            StatusBanner(
              status: _currentState.status,
              message: _currentState.statusMessage,
            ).animate().fadeIn().slideY(begin: -0.5, end: 0),

            // Camera Preview
            Expanded(
              child: Stack(
                children: [
                  // Camera feed
                  if (_isInitialized && _cameraController != null)
                    CameraPreviewWidget(
                      controller: _cameraController!,
                      faceResult: _lastFaceResult,
                      showOverlay: _showDebug,
                    )
                  else
                    _buildLoadingCamera(),

                  // Debug metrics panel
                  if (_showDebug)
                    Positioned(
                      left: 16,
                      top: 16,
                      child: MetricsPanel(
                        state: _currentState,
                        fps: _fps,
                      )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideX(begin: -0.3, end: 0),
                    ),

                  // Monitoring status indicator
                  if (!_isMonitoring)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pause_circle_outline,
                              size: 64,
                              color: AppTheme.warningColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Monitoring Paused',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Control buttons
            ControlButtons(
              isMonitoring: _isMonitoring,
              showDebug: _showDebug,
              onToggleMonitoring: _toggleMonitoring,
              onToggleDebug: _toggleDebug,
              onSwitchCamera: _switchCamera,
              onCalibrate: _openCalibration,
              onClose: () {
                Navigator.of(context).pop();
              },
            ).animate().fadeIn().slideY(begin: 0.5, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCamera() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Initializing camera...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
