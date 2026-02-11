import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/face_analyzer_service.dart';

/// Overlay widget for rendering face detection results.
/// Draws the bounding box, eyes, mouth, and debug info.
class FaceDetectionOverlay extends StatelessWidget {
  const FaceDetectionOverlay({
    super.key,
    required this.result,
    required this.previewSize,
    required this.screenSize,
    this.isMirrored = true,
    this.showDebugInfo = true,
    this.showEyeContours = true,
    this.showMouthContour = true,
  });

  final FaceAnalysisResult result;
  final Size previewSize;
  final Size screenSize;
  final bool isMirrored;
  final bool showDebugInfo;
  final bool showEyeContours;
  final bool showMouthContour;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: screenSize,
      painter: FaceOverlayPainter(
        result: result,
        previewSize: previewSize,
        screenSize: screenSize,
        isMirrored: isMirrored,
        showDebugInfo: showDebugInfo,
        showEyeContours: showEyeContours,
        showMouthContour: showMouthContour,
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter({
    required this.result,
    required this.previewSize,
    required this.screenSize,
    this.isMirrored = true,
    this.showDebugInfo = true,
    this.showEyeContours = true,
    this.showMouthContour = true,
  });

  final FaceAnalysisResult result;
  final Size previewSize;
  final Size screenSize;
  final bool isMirrored;
  final bool showDebugInfo;
  final bool showEyeContours;
  final bool showMouthContour;

  @override
  void paint(Canvas canvas, Size size) {
    if (!result.faceDetected) return;

    // Hitung scale dan offset untuk mapping koordinat
    final scaleX = screenSize.width / previewSize.width;
    final scaleY = screenSize.height / previewSize.height;

    // Face bounding box
    if (result.faceBoundingBox != null) {
      final bbox = result.faceBoundingBox!;
      
      double left = bbox.left * scaleX;
      double right = bbox.right * scaleX;
      final top = bbox.top * scaleY;
      final bottom = bbox.bottom * scaleY;

      // Mirror untuk front camera
      if (isMirrored) {
        final temp = left;
        left = screenSize.width - right;
        right = screenSize.width - temp;
      }

      final faceRect = Rect.fromLTRB(left, top, right, bottom);
      
      // Warna bounding box berdasarkan status
      Color boxColor = Colors.green;
      if (result.isEyesClosed) {
        boxColor = Colors.red;
      } else if (result.isYawning || result.isHeadDown || result.isLookingAway) {
        boxColor = Colors.orange;
      }

      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(faceRect, const Radius.circular(8)),
        boxPaint,
      );

      // Label di atas bounding box
      if (showDebugInfo) {
        _drawStatusLabel(canvas, faceRect, boxColor);
      }
    }

    // Draw eye contours
    if (showEyeContours) {
      final eyePaint = Paint()
        ..color = result.isEyesClosed ? Colors.red : Colors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      if (result.leftEyeContour != null) {
        _drawContour(canvas, result.leftEyeContour!, scaleX, scaleY, eyePaint);
      }
      if (result.rightEyeContour != null) {
        _drawContour(canvas, result.rightEyeContour!, scaleX, scaleY, eyePaint);
      }
    }

    // Draw mouth contour
    if (showMouthContour && result.mouthContour != null) {
      final mouthPaint = Paint()
        ..color = result.isYawning ? Colors.orange : Colors.pink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      _drawContour(canvas, result.mouthContour!, scaleX, scaleY, mouthPaint);
    }

    // Debug info di sudut kiri atas
    if (showDebugInfo) {
      _drawDebugPanel(canvas);
    }
  }

  void _drawContour(
    Canvas canvas,
    List<math.Point<int>> points,
    double scaleX,
    double scaleY,
    Paint paint,
  ) {
    if (points.length < 2) return;

    final path = Path();
    
    for (int i = 0; i < points.length; i++) {
      double x = points[i].x * scaleX;
      final y = points[i].y * scaleY;
      
      if (isMirrored) {
        x = screenSize.width - x;
      }

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStatusLabel(Canvas canvas, Rect faceRect, Color color) {
    final List<String> labels = [];
    
    if (result.isEyesClosed) labels.add('EYES CLOSED');
    if (result.isYawning) labels.add('YAWNING');
    if (result.isHeadDown) labels.add('LOOKING DOWN');
    if (result.isLookingAway) labels.add('LOOKING AWAY');
    if (labels.isEmpty) labels.add('OK');

    final textPainter = TextPainter(
      text: TextSpan(
        text: labels.join(' | '),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: color.withValues(alpha: 0.7),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas, 
      Offset(faceRect.left, faceRect.top - 20),
    );
  }

  void _drawDebugPanel(Canvas canvas) {
    final debugTexts = [
      'EAR: ${result.averageEAR?.toStringAsFixed(3) ?? "N/A"}',
      'MAR: ${result.mar?.toStringAsFixed(3) ?? "N/A"}',
      'Yaw: ${result.headEulerAngleY?.toStringAsFixed(1) ?? "N/A"}°',
      'Pitch: ${result.headEulerAngleX?.toStringAsFixed(1) ?? "N/A"}°',
      'L Eye: ${((result.leftEyeOpenProbability ?? 0) * 100).toInt()}%',
      'R Eye: ${((result.rightEyeOpenProbability ?? 0) * 100).toInt()}%',
    ];

    // Background panel
    const panelRect = Rect.fromLTWH(10, 10, 150, 130);
    final bgPaint = Paint()..color = Colors.black54;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(8)),
      bgPaint,
    );

    double y = 20;
    for (final text in debugTexts) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(20, y));
      y += 18;
    }
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.result != result;
  }
}
