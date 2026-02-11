import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/face_analyzer_service.dart';

class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({
    super.key,
    required this.controller,
    this.faceResult,
    this.showOverlay = true,
  });
  final CameraController controller;
  final FaceAnalysisResult? faceResult;
  final bool showOverlay;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final lensDirection = controller.description.lensDirection;
    final isFrontCamera = lensDirection == CameraLensDirection.front;
    // Some devices report the non-front camera as `external`.
    final isRearCamera = lensDirection == CameraLensDirection.back ||
        lensDirection == CameraLensDirection.external;
    // Mirror the preview horizontally.
    // Front camera: mirror like a selfie view.
    // Rear camera: user requested it to be flipped.
    final isMirrored = isFrontCamera || isRearCamera;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate scale to fit the preview
        final previewSize = controller.value.previewSize!;
        final screenRatio = constraints.maxWidth / constraints.maxHeight;
        final previewRatio = previewSize.height / previewSize.width;

        return ClipRect(
          child: OverflowBox(
            maxWidth: screenRatio > previewRatio
                ? constraints.maxHeight * previewRatio
                : constraints.maxWidth,
            maxHeight: screenRatio > previewRatio
                ? constraints.maxHeight
                : constraints.maxWidth / previewRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview with mirroring
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(
                      isMirrored ? -1.0 : 1.0,
                      1.0,
                      1.0,
                      1.0,
                    ),
                  child: CameraPreview(controller),
                ),

                // Face overlay
                if (showOverlay && faceResult != null)
                  CustomPaint(
                    painter: FaceOverlayPainter(
                      faceResult: faceResult!,
                      previewSize: previewSize,
                      screenSize:
                          Size(constraints.maxWidth, constraints.maxHeight),
                      isMirrored: isMirrored,
                    ),
                  ),

                // Corner guides
                if (showOverlay) _buildCornerGuides(constraints),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCornerGuides(BoxConstraints constraints) {
    final guideColor = faceResult?.faceDetected == true
        ? AppTheme.safeColor
        : AppTheme.primaryColor;
    const guideLength = 40.0;
    const guideThickness = 3.0;
    const cornerRadius = 8.0;
    const padding = 32.0;

    return Stack(
      children: [
        // Top-left corner
        Positioned(
          left: padding,
          top: padding,
          child: _buildCorner(guideColor, guideLength, guideThickness,
              cornerRadius, true, true),
        ),
        // Top-right corner
        Positioned(
          right: padding,
          top: padding,
          child: _buildCorner(guideColor, guideLength, guideThickness,
              cornerRadius, false, true),
        ),
        // Bottom-left corner
        Positioned(
          left: padding,
          bottom: padding,
          child: _buildCorner(guideColor, guideLength, guideThickness,
              cornerRadius, true, false),
        ),
        // Bottom-right corner
        Positioned(
          right: padding,
          bottom: padding,
          child: _buildCorner(guideColor, guideLength, guideThickness,
              cornerRadius, false, false),
        ),
      ],
    );
  }

  Widget _buildCorner(
    Color color,
    double length,
    double thickness,
    double radius,
    bool isLeft,
    bool isTop,
  ) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: CornerPainter(
          color: color,
          thickness: thickness,
          radius: radius,
          isLeft: isLeft,
          isTop: isTop,
        ),
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter({
    required this.faceResult,
    required this.previewSize,
    required this.screenSize,
    required this.isMirrored,
  });
  final FaceAnalysisResult faceResult;
  final Size previewSize;
  final Size screenSize;
  final bool isMirrored;

  @override
  void paint(Canvas canvas, Size size) {
    if (!faceResult.faceDetected) return;

    final scaleX = size.width / previewSize.height;
    final scaleY = size.height / previewSize.width;

    // Draw face bounding box
    if (faceResult.faceBoundingBox != null) {
      final rect = faceResult.faceBoundingBox!;

      double left = rect.left * scaleX;
      final double top = rect.top * scaleY;
      double right = rect.right * scaleX;
      final double bottom = rect.bottom * scaleY;

      // Mirror when preview is mirrored
      if (isMirrored) {
        final temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      final paint = Paint()
        ..color = faceResult.isEyesClosed || faceResult.isYawning
            ? AppTheme.dangerColor.withValues(alpha: 0.8)
            : AppTheme.safeColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(12),
      );
      canvas.drawRRect(rrect, paint);
    }

    // Draw eye contours
    final eyePaint = Paint()
      ..color = faceResult.isEyesClosed
          ? AppTheme.dangerColor
          : AppTheme.secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    void drawContour(List<math.Point<int>>? contour) {
      if (contour == null || contour.isEmpty) return;

      final path = Path();
      for (int i = 0; i < contour.length; i++) {
        double x = contour[i].x * scaleX;
        final double y = contour[i].y * scaleY;

        if (isMirrored) {
          x = size.width - x;
        }

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, eyePaint);
    }

    drawContour(faceResult.leftEyeContour);
    drawContour(faceResult.rightEyeContour);

    // Draw mouth contour
    if (faceResult.mouthContour != null) {
      final mouthPaint = Paint()
        ..color = faceResult.isYawning
            ? AppTheme.warningColor
            : AppTheme.secondaryColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final path = Path();
      for (int i = 0; i < faceResult.mouthContour!.length; i++) {
        double x = faceResult.mouthContour![i].x * scaleX;
        final double y = faceResult.mouthContour![i].y * scaleY;

        if (isMirrored) {
          x = size.width - x;
        }

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.faceResult != faceResult;
  }
}

class CornerPainter extends CustomPainter {
  CornerPainter({
    required this.color,
    required this.thickness,
    required this.radius,
    required this.isLeft,
    required this.isTop,
  });
  final Color color;
  final double thickness;
  final double radius;
  final bool isLeft;
  final bool isTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isLeft && isTop) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
      path.lineTo(size.width, 0);
    } else if (!isLeft && isTop) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      path.lineTo(size.width, size.height);
    } else if (isLeft && !isTop) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - radius);
      path.quadraticBezierTo(0, size.height, radius, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - radius);
      path.quadraticBezierTo(
          size.width, size.height, size.width - radius, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
