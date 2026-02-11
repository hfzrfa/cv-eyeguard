import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Eye Aspect Ratio (EAR) - deteksi mata tertutup
/// Mouth Aspect Ratio (MAR) - deteksi menguap
/// Head Pose - deteksi kepala menunduk/melihat samping

class FaceAnalysisResult {
  FaceAnalysisResult({
    this.leftEAR,
    this.rightEAR,
    this.averageEAR,
    this.mar,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.faceDetected = false,
    this.faceBoundingBox,
    this.leftEyeContour,
    this.rightEyeContour,
    this.mouthContour,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.imageSize,
    this.debugInfo,
  });

  factory FaceAnalysisResult.noFace([String? debugInfo]) => FaceAnalysisResult(
    faceDetected: false,
    debugInfo: debugInfo,
  );

  final double? leftEAR;
  final double? rightEAR;
  final double? averageEAR;
  final double? mar;
  final double? headEulerAngleX; // Pitch (menunduk/mendongak)
  final double? headEulerAngleY; // Yaw (kiri/kanan)
  final double? headEulerAngleZ; // Roll (miring)
  final bool faceDetected;
  final ui.Rect? faceBoundingBox;
  final List<math.Point<int>>? leftEyeContour;
  final List<math.Point<int>>? rightEyeContour;
  final List<math.Point<int>>? mouthContour;
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final ui.Size? imageSize;
  final String? debugInfo;

  bool get isEyesClosed {
    // Gunakan probabilitas mata terbuka sebagai fallback utama
    if (leftEyeOpenProbability != null && rightEyeOpenProbability != null) {
      final avgProb = (leftEyeOpenProbability! + rightEyeOpenProbability!) / 2.0;
      return avgProb < 0.3;
    }
    if (averageEAR == null) return false;
    return averageEAR! < 0.2;
  }

  bool get isYawning {
    // Cek apakah mulut terbuka lebar
    if (mar == null) return false;
    return mar! > 0.55;
  }

  bool get isLookingAway {
    if (headEulerAngleY == null) return false;
    return headEulerAngleY!.abs() > 25;
  }

  bool get isHeadDown {
    if (headEulerAngleX == null) return false;
    return headEulerAngleX! < -10;
  }
}

class FaceAnalyzerService {
  FaceDetector? _faceDetector;
  bool _isInitialized = false;
  int _processCount = 0;
  int _faceFoundCount = 0;
  
  /// Debug info untuk troubleshooting
  String get debugStats => 'Processed: $_processCount, Found: $_faceFoundCount';

  Future<void> initialize() async {
    if (_isInitialized && _faceDetector != null) return;

    // Gunakan konfigurasi optimal untuk mobile face detection
    final options = FaceDetectorOptions(
      enableClassification: true, // Untuk eye open probability
      enableContours: true,       // Untuk EAR/MAR calculation
      enableTracking: true,       // Untuk tracking wajah
      enableLandmarks: true,      // Untuk landmark points
      performanceMode: FaceDetectorMode.accurate, // Mode akurat
      minFaceSize: 0.05, // Ukuran minimal wajah 5% dari gambar (lebih kecil = lebih mudah deteksi)
    );

    _faceDetector = FaceDetector(options: options);
    _isInitialized = true;
    debugPrint('[FaceAnalyzer] ✅ Initialized with accurate mode, minFaceSize: 0.05');
  }

  Future<FaceAnalysisResult> analyzeImage(InputImage inputImage) async {
    if (!_isInitialized || _faceDetector == null) {
      await initialize();
    }
    
    _processCount++;

    try {
      final faces = await _faceDetector!.processImage(inputImage);
      
      if (faces.isEmpty) {
        if (_processCount % 30 == 0) {
          debugPrint('[FaceAnalyzer] ℹ️ No face detected (frame $_processCount)');
        }
        return FaceAnalysisResult.noFace('No faces in frame');
      }

      _faceFoundCount++;
      final face = faces.first;
      
      debugPrint('[FaceAnalyzer] ✅ Face detected! BBox: ${face.boundingBox}, '
          'LeftEye: ${face.leftEyeOpenProbability?.toStringAsFixed(2)}, '
          'RightEye: ${face.rightEyeOpenProbability?.toStringAsFixed(2)}, '
          'Yaw: ${face.headEulerAngleY?.toStringAsFixed(1)}, '
          'Pitch: ${face.headEulerAngleX?.toStringAsFixed(1)}');

      // Get contours for EAR/MAR calculation
      final leftEyeContour = face.contours[FaceContourType.leftEye]?.points;
      final rightEyeContour = face.contours[FaceContourType.rightEye]?.points;
      final upperLipTop = face.contours[FaceContourType.upperLipTop]?.points;
      final lowerLipBottom = face.contours[FaceContourType.lowerLipBottom]?.points;

      // Calculate EAR dari contour (jika tersedia)
      double? leftEAR;
      double? rightEAR;
      double? averageEAR;

      if (leftEyeContour != null && leftEyeContour.length >= 6) {
        leftEAR = _calculateEAR(leftEyeContour);
      }
      if (rightEyeContour != null && rightEyeContour.length >= 6) {
        rightEAR = _calculateEAR(rightEyeContour);
      }
      
      // Prioritaskan eye open probability dari ML Kit (lebih reliable)
      final leftProb = face.leftEyeOpenProbability;
      final rightProb = face.rightEyeOpenProbability;
      
      if (leftProb != null && rightProb != null) {
        // Konversi probability ke EAR-like value
        // Open (1.0) ≈ EAR 0.35, Closed (0.0) ≈ EAR 0.1
        final leftEARFromProb = 0.1 + (leftProb * 0.25);
        final rightEARFromProb = 0.1 + (rightProb * 0.25);
        
        // Gunakan nilai dari probability sebagai fallback atau rata-rata
        leftEAR ??= leftEARFromProb;
        rightEAR ??= rightEARFromProb;
        
        averageEAR = (leftEAR + rightEAR) / 2.0;
      } else if (leftEAR != null && rightEAR != null) {
        averageEAR = (leftEAR + rightEAR) / 2.0;
      }

      // Calculate MAR (Mouth Aspect Ratio)
      double? mar;
      if (upperLipTop != null && lowerLipBottom != null) {
        mar = _calculateMAR(upperLipTop, lowerLipBottom);
      }

      // Get mouth contour for visualization
      List<math.Point<int>>? mouthContour;
      if (upperLipTop != null && lowerLipBottom != null) {
        mouthContour = [...upperLipTop, ...lowerLipBottom.reversed];
      }

      return FaceAnalysisResult(
        faceDetected: true,
        leftEAR: leftEAR,
        rightEAR: rightEAR,
        averageEAR: averageEAR,
        mar: mar,
        headEulerAngleX: face.headEulerAngleX,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
        faceBoundingBox: face.boundingBox,
        leftEyeContour: leftEyeContour,
        rightEyeContour: rightEyeContour,
        mouthContour: mouthContour,
        smilingProbability: face.smilingProbability,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        imageSize: inputImage.metadata?.size,
        debugInfo: 'Face found at ${face.boundingBox}',
      );
    } catch (e, stack) {
      debugPrint('[FaceAnalyzer] ❌ Error: $e');
      debugPrint('[FaceAnalyzer] Stack: $stack');
      return FaceAnalysisResult.noFace('Error: $e');
    }
  }

  double _calculateEAR(List<math.Point<int>> eyeContour) {
    // Eye Aspect Ratio formula:
    // EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
    // ML Kit eye contour has 16 points forming an ellipse

    if (eyeContour.length < 8) return 0.25; // Default jika tidak cukup points

    final n = eyeContour.length;
    
    // Ambil points dari posisi yang berbeda di contour
    // Index: 0=left, n/4=top, n/2=right, 3n/4=bottom (approximate)
    final p1 = eyeContour[0]; // Left corner
    final p4 = eyeContour[n ~/ 2]; // Right corner
    
    // Vertical points
    final topIdx = n ~/ 4;
    final bottomIdx = (n * 3) ~/ 4;
    
    final p2 = eyeContour[topIdx];
    final p6 = eyeContour[bottomIdx];
    
    // Sedikit offset untuk p3 dan p5
    final p3 = eyeContour[(topIdx + 1).clamp(0, n - 1)];
    final p5 = eyeContour[(bottomIdx - 1).clamp(0, n - 1)];

    final v1 = _euclideanDistance(p2, p6);
    final v2 = _euclideanDistance(p3, p5);
    final h = _euclideanDistance(p1, p4);

    if (h <= 1.0) return 0.25;
    return (v1 + v2) / (2.0 * h);
  }

  double _calculateMAR(List<math.Point<int>> upperLip, List<math.Point<int>> lowerLip) {
    // MAR = vertical distance / horizontal distance

    if (upperLip.isEmpty || lowerLip.isEmpty) return 0.0;

    // Find center points
    final upperCenter = upperLip[upperLip.length ~/ 2];
    final lowerCenter = lowerLip[lowerLip.length ~/ 2];

    // Vertical distance (mouth opening)
    final verticalDist = (lowerCenter.y - upperCenter.y).abs().toDouble();

    // Horizontal distance (mouth width) dari upper lip corners
    final leftCorner = upperLip.first;
    final rightCorner = upperLip.last;
    final horizontalDist = _euclideanDistance(leftCorner, rightCorner);

    if (horizontalDist <= 1.0) return 0.0;
    return verticalDist / horizontalDist;
  }

  double _euclideanDistance(math.Point<int> p1, math.Point<int> p2) {
    final dx = (p1.x - p2.x).toDouble();
    final dy = (p1.y - p2.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  Future<void> dispose() async {
    if (_isInitialized && _faceDetector != null) {
      await _faceDetector!.close();
      _faceDetector = null;
      _isInitialized = false;
      debugPrint('[FaceAnalyzer] Disposed. Stats: $debugStats');
    }
  }
}

/// Extension untuk konversi CameraImage ke InputImage ML Kit
/// INI ADALAH BAGIAN PALING KRITIS - rotation harus benar untuk face detection
extension CameraImageExtension on CameraImage {
  /// Konversi CameraImage ke InputImage dengan handling yang benar untuk Android
  InputImage toInputImage(CameraDescription camera, [int? deviceOrientation]) {
    final sensorOrientation = camera.sensorOrientation;
    final isFrontCamera = camera.lensDirection == CameraLensDirection.front;
    
    // Hitung rotation berdasarkan sensor orientation
    InputImageRotation rotation;
    if (Platform.isAndroid) {
      // Gunakan sensor orientation langsung
      rotation = _rotationIntToImageRotation(sensorOrientation);
    } else {
      rotation = InputImageRotation.rotation0deg;
    }
    
    // Konversi bytes sesuai format
    final bytes = _convertToNv21();
    final imageSize = ui.Size(width.toDouble(), height.toDouble());

    debugPrint('[CameraImage] Size: ${width}x$height, '
        'sensor: $sensorOrientation, front: $isFrontCamera, '
        'rotation: $rotation, format: ${format.group}, '
        'planes: ${planes.length}');

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: width,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
  
  /// Konversi YUV420/NV21 ke format yang benar untuk ML Kit
  Uint8List _convertToNv21() {
    // Camera plugin biasanya kirim YUV420 (3 planes). Konversi harus pakai
    // rowStride + pixelStride, kalau tidak ML Kit sering gagal deteksi.

    if (planes.length == 1) {
      return planes.first.bytes;
    }

    final yPlane = planes[0];
    final yRowStride = yPlane.bytesPerRow;
    final ySize = width * height;
    final uvSize = (width * height) ~/ 2;
    final result = Uint8List(ySize + uvSize);

    // Copy Y plane (strip padding)
    for (int row = 0; row < height; row++) {
      final srcStart = row * yRowStride;
      final dstStart = row * width;
      result.setRange(dstStart, dstStart + width, yPlane.bytes, srcStart);
    }

    // Semi-planar: Y + interleaved UV plane
    if (planes.length == 2) {
      final uvPlane = planes[1];
      final uvRowStride = uvPlane.bytesPerRow;

      int dstIndex = ySize;
      final uvHeight = height ~/ 2;

      for (int row = 0; row < uvHeight; row++) {
        final srcStart = row * uvRowStride;
        // For NV21/NV12 interleaved plane, each row contains `width` bytes.
        result.setRange(dstIndex, dstIndex + width, uvPlane.bytes, srcStart);
        dstIndex += width;
      }

      return result;
    }

    // Planar: Y, U, V
    if (planes.length >= 3) {
      final uPlane = planes[1];
      final vPlane = planes[2];

      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;

      int dstIndex = ySize;
      final uvWidth = width ~/ 2;
      final uvHeight = height ~/ 2;

      for (int row = 0; row < uvHeight; row++) {
        for (int col = 0; col < uvWidth; col++) {
          final uvIndex = row * uvRowStride + col * uvPixelStride;
          if (uvIndex < vPlane.bytes.length && uvIndex < uPlane.bytes.length) {
            result[dstIndex++] = vPlane.bytes[uvIndex];
            result[dstIndex++] = uPlane.bytes[uvIndex];
          }
        }
      }

      return result;
    }

    return result;
  }
  
  /// Konversi int rotation ke InputImageRotation
  static InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
  
  /// Alternative: Konversi ke InputImage menggunakan rotasi eksplisit
  InputImage toInputImageWithRotation(
    CameraDescription camera, 
    InputImageRotation rotation,
  ) {
    final bytes = _convertToNv21();
    final imageSize = ui.Size(width.toDouble(), height.toDouble());

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}
