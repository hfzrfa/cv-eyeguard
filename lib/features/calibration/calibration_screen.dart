import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/face_analyzer_service.dart';
import '../../core/services/drowsiness_detector_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/face_detection_overlay.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;

  late FaceAnalyzerService _faceAnalyzer;
  late TTSService _ttsService;
  late StorageService _storageService;

  int _currentStep = 0;
  bool _isCollecting = false;
  int _countdown = 3;
  double _collectProgress = 0;
  final List<double> _earSamples = [];

  // Face detection state
  bool _faceDetected = false;
  bool _calibrationStarted = false;
  bool _waitingForFace = true;
  FaceAnalysisResult _lastFaceResult = FaceAnalysisResult.noFace();

  // Rotation testing untuk mencari rotation yang benar
  int _currentRotationIndex = 0;
  int _failedDetections = 0;
  static const int _rotationTestThreshold =
      30; // Test rotation setelah N frame gagal
  final List<InputImageRotation> _rotationsToTry = [
    InputImageRotation.rotation0deg,
    InputImageRotation.rotation90deg,
    InputImageRotation.rotation180deg,
    InputImageRotation.rotation270deg,
  ];
  InputImageRotation? _workingRotation;

  // Calibration data
  double _earWideOpen = 0;
  double _earNormal = 0;
  double _earSquint = 0;
  double _earClosed = 0;
  double _currentEAR = 0;

  final List<_CalibrationStep> _steps = [
    _CalibrationStep(
      key: 'wide_open',
      title: 'EYES WIDE OPEN',
      instruction: 'Open your eyes as wide as possible',
      color: AppTheme.safeColor,
      icon: Icons.visibility,
    ),
    _CalibrationStep(
      key: 'normal',
      title: 'NORMAL / RELAXED',
      instruction: 'Relax your eyes naturally',
      color: AppTheme.primaryColor,
      icon: Icons.remove_red_eye,
    ),
    _CalibrationStep(
      key: 'squint',
      title: 'SQUINT (DROWSY)',
      instruction: 'Squint your eyes like you are getting sleepy',
      color: AppTheme.warningColor,
      icon: Icons.bedtime,
    ),
    _CalibrationStep(
      key: 'closed',
      title: 'CLOSE YOUR EYES',
      instruction: 'Close your eyes completely',
      color: AppTheme.dangerColor,
      icon: Icons.visibility_off,
    ),
  ];

  Timer? _countdownTimer;
  Timer? _collectTimer;
  bool _isExiting = false;

  Future<void> _releaseCamera() async {
    final controller = _cameraController;
    _cameraController = null;

    try {
      if (controller != null && controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Ignore: stream may already be stopped.
    }

    try {
      await controller?.dispose();
    } catch (_) {
      // Ignore: controller may already be disposed.
    }

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _exitCalibration() async {
    if (_isExiting) return;
    _isExiting = true;

    final navigator = Navigator.of(context);
    _countdownTimer?.cancel();
    _collectTimer?.cancel();
    await _releaseCamera();
    if (!mounted) return;
    navigator.pop();
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _faceAnalyzer = FaceAnalyzerService();
    _ttsService = TTSService();
    _storageService = StorageService();

    await _faceAnalyzer.initialize();
    await _ttsService.initialize();
    await _storageService.initialize();

    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    CameraDescription? frontCamera;
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }
    frontCamera ??= cameras.first;

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();

      debugPrint('[Calibration] Camera initialized: '
          '${_cameraController!.value.previewSize}, '
          'sensor: ${frontCamera.sensorOrientation}');

      if (mounted) {
        setState(() => _isInitialized = true);
        await _cameraController!.startImageStream(_processImage);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    try {
      final camera = _cameraController!.description;
      InputImage inputImage;

      // Jika sudah menemukan rotation yang bekerja, gunakan itu
      if (_workingRotation != null) {
        inputImage = image.toInputImageWithRotation(camera, _workingRotation!);
      } else {
        // Gunakan rotation default terlebih dahulu
        inputImage = image.toInputImage(camera);
      }

      final faceResult = await _faceAnalyzer.analyzeImage(inputImage);

      final faceNowDetected =
          faceResult.faceDetected && faceResult.averageEAR != null;

      // Rotation testing: jika banyak frame gagal deteksi, coba rotation lain
      if (!faceNowDetected && _workingRotation == null) {
        _failedDetections++;

        if (_failedDetections >= _rotationTestThreshold) {
          // Coba rotation berikutnya
          _currentRotationIndex =
              (_currentRotationIndex + 1) % _rotationsToTry.length;
          _failedDetections = 0;

          debugPrint(
              '[Calibration] Testing rotation: ${_rotationsToTry[_currentRotationIndex]}');

          // Coba dengan rotation baru
          final testImage = image.toInputImageWithRotation(
            camera,
            _rotationsToTry[_currentRotationIndex],
          );
          final testResult = await _faceAnalyzer.analyzeImage(testImage);

          if (testResult.faceDetected) {
            _workingRotation = _rotationsToTry[_currentRotationIndex];
            debugPrint(
                '[Calibration] ✅ Found working rotation: $_workingRotation');
          }
        }
      } else if (faceNowDetected && _workingRotation == null) {
        // Deteksi berhasil dengan rotation default, simpan
        _workingRotation =
            InputImageRotation.rotation270deg; // Default untuk front camera
        debugPrint('[Calibration] ✅ Default rotation works!');
      }

      setState(() {
        _faceDetected = faceNowDetected;
        _lastFaceResult = faceResult;
        if (faceNowDetected) {
          _currentEAR = faceResult.averageEAR!;
          _failedDetections = 0; // Reset counter
        }
      });

      if (faceNowDetected) {
        // Auto-start calibration when face first detected
        if (!_calibrationStarted && _waitingForFace) {
          _calibrationStarted = true;
          _waitingForFace = false;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _startStep();
          });
        }

        if (_isCollecting) {
          _earSamples.add(_currentEAR);
        }
      }
    } catch (e) {
      debugPrint('Image processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _startStep() {
    if (_currentStep >= _steps.length) {
      _finishCalibration();
      return;
    }

    final step = _steps[_currentStep];
    _ttsService.speak(step.instruction, category: 'calibration');

    setState(() {
      _countdown = 3;
      _isCollecting = false;
      _collectProgress = 0;
      _earSamples.clear();
    });

    // Countdown - only proceeds when face is detected
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Only decrement countdown when face is detected
      if (_faceDetected) {
        // Use millisecond-based countdown for smoother UX
        setState(() {
          // Decrement every ~1 second (10 x 100ms)
        });

        // Check if 1 second has passed (using timer tick count)
        if (timer.tick % 10 == 0 && timer.tick > 0) {
          if (_countdown > 1) {
            setState(() => _countdown--);
          } else {
            timer.cancel();
            _startCollecting();
          }
        }
      }
      // If face not detected, countdown pauses (timer continues but countdown doesn't decrement)
    });
  }

  void _startCollecting() {
    _ttsService.speak('Tahan posisi', category: 'calibration_hold');

    setState(() {
      _isCollecting = true;
      _collectProgress = 0;
    });

    const collectDuration = Duration(seconds: 2);
    const updateInterval = Duration(milliseconds: 50);
    int elapsed = 0;

    _collectTimer?.cancel();
    _collectTimer = Timer.periodic(updateInterval, (timer) {
      elapsed += updateInterval.inMilliseconds;
      final progress = elapsed / collectDuration.inMilliseconds;

      if (progress >= 1.0) {
        timer.cancel();
        _finishStep();
      } else {
        setState(() => _collectProgress = progress);
      }
    });
  }

  void _finishStep() {
    if (_earSamples.isEmpty) return;

    final avgEAR = _earSamples.reduce((a, b) => a + b) / _earSamples.length;
    final step = _steps[_currentStep];

    setState(() {
      switch (step.key) {
        case 'wide_open':
          _earWideOpen = avgEAR;
          break;
        case 'normal':
          _earNormal = avgEAR;
          break;
        case 'squint':
          _earSquint = avgEAR;
          break;
        case 'closed':
          _earClosed = avgEAR;
          break;
      }
      _isCollecting = false;
      _currentStep++;
    });

    // Start next step after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startStep();
    });
  }

  Future<void> _finishCalibration() async {
    final calibration = CalibrationData(
      earWideOpen: _earWideOpen,
      earNormal: _earNormal,
      earSquint: _earSquint,
      earClosed: _earClosed,
      calibrated: true,
      calibrationDate: DateTime.now(),
    );

    await _storageService.saveCalibration(calibration);

    _ttsService.speak(
      'Calibration complete. Your data has been saved.',
      category: 'calibration_done',
    );

    if (mounted) {
      _showCompletionDialog(calibration);
    }
  }

  void _showCompletionDialog(CalibrationData calibration) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.safeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.safeColor,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Calibration Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('Eyes wide open', calibration.earWideOpen),
            _buildResultRow('Normal eyes', calibration.earNormal),
            _buildResultRow('Squint', calibration.earSquint),
            _buildResultRow('Eyes closed', calibration.earClosed),
            const Divider(height: 24),
            _buildResultRow(
              'Threshold optimal',
              calibration.computeThreshold(),
              highlight: true,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Close dialog first, then release camera and exit screen.
                Navigator.of(context).pop();
                await _exitCalibration();
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, double value, {bool highlight = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              color: highlight ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _collectTimer?.cancel();
    _cameraController?.dispose();
    _faceAnalyzer.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Intercept Android back/gesture and release camera before popping.
        if (didPop) return;
        await _exitCalibration();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text('Eye Calibration'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await _exitCalibration();
            },
          ),
        ),
        body: _isInitialized ? _buildContent() : _buildLoading(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text('Initializing camera...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_currentStep >= _steps.length) {
      return _buildCompleteSummary();
    }

    // Show waiting for face screen before calibration starts
    final step = _waitingForFace ? null : _steps[_currentStep];
    final headerColor = step?.color ?? AppTheme.primaryColor;
    final headerIcon = step?.icon ?? Icons.face_retouching_natural;
    final headerTitle = step?.title ?? 'CALIBRATION SETUP';
    final headerInstruction =
        step?.instruction ?? 'Position your face in front of the camera';

    return Column(
      children: [
        // Step header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: headerColor,
            boxShadow: [
              BoxShadow(
                color: headerColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(headerIcon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                headerTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                headerInstruction,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.3, end: 0),

        // Camera preview
        Expanded(
          child: Stack(
            children: [
              if (_cameraController != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..scaleByDouble(
                                  _cameraController!
                                              .description.lensDirection ==
                                          CameraLensDirection.front
                                      ? -1.0
                                      : 1.0,
                                  1.0,
                                  1.0,
                                  1.0,
                                ),
                              child: CameraPreview(_cameraController!),
                            ),
                            // Face detection overlay
                            if (_lastFaceResult.faceDetected)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return FaceDetectionOverlay(
                                    result: _lastFaceResult,
                                    previewSize: Size(
                                      _cameraController!
                                              .value.previewSize?.height ??
                                          480,
                                      _cameraController!
                                              .value.previewSize?.width ??
                                          640,
                                    ),
                                    screenSize: Size(constraints.maxWidth,
                                        constraints.maxHeight),
                                    isMirrored: _cameraController!
                                            .description.lensDirection ==
                                        CameraLensDirection.front,
                                    showDebugInfo: true,
                                    showEyeContours: true,
                                    showMouthContour: true,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // EAR value and face detection status display
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _faceDetected
                          ? AppTheme.safeColor
                          : AppTheme.dangerColor,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _faceDetected
                                ? Icons.face
                                : Icons.face_retouching_off,
                            color: _faceDetected
                                ? AppTheme.safeColor
                                : AppTheme.dangerColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _faceDetected
                                ? 'Face detected'
                                : 'Face not detected',
                            style: TextStyle(
                              color: _faceDetected
                                  ? AppTheme.safeColor
                                  : AppTheme.dangerColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_faceDetected) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'EAR: ',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                            Text(
                              _currentEAR.toStringAsFixed(3),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Countdown or progress
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: _buildProgressSection(),
              ),
            ],
          ),
        ),

        // Step indicators
        _buildStepIndicators(),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProgressSection() {
    final colorScheme = Theme.of(context).colorScheme;
    // Waiting for face detection before starting
    if (_waitingForFace) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              _faceDetected
                  ? Icons.check_circle
                  : Icons.face_retouching_natural,
              size: 48,
              color: _faceDetected ? AppTheme.safeColor : AppTheme.warningColor,
            ),
            const SizedBox(height: 12),
            Text(
              _faceDetected
                  ? 'Face detected! Starting...'
                  : 'Position your face in front of the camera',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _faceDetected
                        ? AppTheme.safeColor
                        : AppTheme.warningColor,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!_faceDetected) ...[
              const SizedBox(height: 8),
              Text(
                'Make sure lighting is sufficient',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    if (!_isCollecting) {
      // Show countdown - with face detection status
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (!_faceDetected) ...[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningColor,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Face not detected — countdown paused',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.warningColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _faceDetected ? 'Starting in' : 'Paused',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _faceDetected
                        ? colorScheme.onSurfaceVariant
                        : AppTheme.warningColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_countdown',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: _faceDetected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  duration: 500.ms,
                  curve: Curves.easeInOut,
                ),
          ],
        ),
      );
    }

    // Show collection progress
    final currentColor = _currentStep < _steps.length
        ? _steps[_currentStep].color
        : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Collecting data... ${(_collectProgress * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.safeColor,
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _collectProgress,
              backgroundColor: colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(currentColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_steps.length, (index) {
          final isActive = !_waitingForFace && index == _currentStep;
          final isCompleted = !_waitingForFace && index < _currentStep;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 32 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.safeColor
                  : (isActive ? _steps[index].color : AppTheme.borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCompleteSummary() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          Text(
            'Saving calibration data...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _CalibrationStep {
  _CalibrationStep({
    required this.key,
    required this.title,
    required this.instruction,
    required this.color,
    required this.icon,
  });
  final String key;
  final String title;
  final String instruction;
  final Color color;
  final IconData icon;
}
