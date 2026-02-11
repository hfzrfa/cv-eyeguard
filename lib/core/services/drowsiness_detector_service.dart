import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'face_analyzer_service.dart';

/// Status keseluruhan pengguna
enum DriverStatus {
  safe,       // Aman
  drowsy,     // Mengantuk
  distracted, // Terdistraksi
  danger,     // Bahaya (kombinasi)
}

/// Alasan spesifik untuk status
enum AlertReason {
  none,
  eyesClosed,     // Mata tertutup lama
  yawning,        // Menguap
  headDown,       // Kepala menunduk
  lookingAway,    // Melihat samping
  noFaceDetected, // Wajah tidak terdeteksi
  phonDetected,   // HP terdeteksi (future)
  perclosHigh,    // PERCLOS tinggi
}

class DrowsinessState {

  DrowsinessState({
    this.status = DriverStatus.safe,
    this.alertReason = AlertReason.none,
    this.ear = 0.0,
    this.mar = 0.0,
    this.perclos = 0.0,
    this.headPitch,
    this.headYaw,
    this.headRoll,
    this.eyeClosedFrames = 0,
    this.yawnFrames = 0,
    this.headDownFrames = 0,
    this.faceDetected = false,
    this.statusMessage = 'Initializing...',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  final DriverStatus status;
  final AlertReason alertReason;
  final double ear;
  final double mar;
  final double perclos;
  final double? headPitch;
  final double? headYaw;
  final double? headRoll;
  final int eyeClosedFrames;
  final int yawnFrames;
  final int headDownFrames;
  final bool faceDetected;
  final String statusMessage;
  final DateTime timestamp;

  DrowsinessState copyWith({
    DriverStatus? status,
    AlertReason? alertReason,
    double? ear,
    double? mar,
    double? perclos,
    double? headPitch,
    double? headYaw,
    double? headRoll,
    int? eyeClosedFrames,
    int? yawnFrames,
    int? headDownFrames,
    bool? faceDetected,
    String? statusMessage,
  }) {
    return DrowsinessState(
      status: status ?? this.status,
      alertReason: alertReason ?? this.alertReason,
      ear: ear ?? this.ear,
      mar: mar ?? this.mar,
      perclos: perclos ?? this.perclos,
      headPitch: headPitch ?? this.headPitch,
      headYaw: headYaw ?? this.headYaw,
      headRoll: headRoll ?? this.headRoll,
      eyeClosedFrames: eyeClosedFrames ?? this.eyeClosedFrames,
      yawnFrames: yawnFrames ?? this.yawnFrames,
      headDownFrames: headDownFrames ?? this.headDownFrames,
      faceDetected: faceDetected ?? this.faceDetected,
      statusMessage: statusMessage ?? this.statusMessage,
      timestamp: DateTime.now(),
    );
  }
}

class DrowsinessDetectorConfig {

  DrowsinessDetectorConfig({
    this.earThreshold = 0.21,
    this.earConsecFrames = 15,
    this.perclosWindow = 90,
    this.perclosThreshold = 0.30,
    this.marThreshold = 0.55,
    this.yawnConsecFrames = 8,
    this.yawAbsThreshold = 25.0,
    this.pitchDownThreshold = 10.0,
    this.pitchDownConsecFrames = 15,
  });
  // EAR thresholds
  double earThreshold;
  int earConsecFrames;
  
  // PERCLOS
  int perclosWindow;
  double perclosThreshold;
  
  // MAR (Yawn) thresholds
  double marThreshold;
  int yawnConsecFrames;
  
  // Head pose thresholds
  double yawAbsThreshold;
  double pitchDownThreshold;
  int pitchDownConsecFrames;
}

class CalibrationData {

  CalibrationData({
    this.earWideOpen = 0.35,
    this.earNormal = 0.28,
    this.earSquint = 0.22,
    this.earClosed = 0.15,
    this.calibrated = false,
    this.calibrationDate,
  });

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
      earWideOpen: (json['earWideOpen'] as num?)?.toDouble() ?? 0.35,
      earNormal: (json['earNormal'] as num?)?.toDouble() ?? 0.28,
      earSquint: (json['earSquint'] as num?)?.toDouble() ?? 0.22,
      earClosed: (json['earClosed'] as num?)?.toDouble() ?? 0.15,
      calibrated: json['calibrated'] as bool? ?? false,
      calibrationDate: json['calibrationDate'] != null 
          ? DateTime.tryParse(json['calibrationDate'] as String)
          : null,
    );
  }
  final double earWideOpen;
  final double earNormal;
  final double earSquint;
  final double earClosed;
  final bool calibrated;
  final DateTime? calibrationDate;

  double computeThreshold() {
    if (!calibrated) return 0.21;
    return (earSquint + earClosed) / 2;
  }

  Map<String, dynamic> toJson() => {
    'earWideOpen': earWideOpen,
    'earNormal': earNormal,
    'earSquint': earSquint,
    'earClosed': earClosed,
    'calibrated': calibrated,
    'calibrationDate': calibrationDate?.toIso8601String(),
  };
}

class DrowsinessDetectorService {

  DrowsinessDetectorService({
    DrowsinessDetectorConfig? config,
    this.onStateChanged,
    this.onAlert,
  }) : config = config ?? DrowsinessDetectorConfig();
  final DrowsinessDetectorConfig config;
  
  // State tracking
  final Queue<bool> _closedHistory = Queue();
  int _eyeClosedFrames = 0;
  int _yawnFrames = 0;
  int _pitchDownFrames = 0;
  
  // Callbacks
  final void Function(DrowsinessState state)? onStateChanged;
  final void Function(AlertReason reason, String message)? onAlert;
  
  DrowsinessState _currentState = DrowsinessState();

  DrowsinessState get currentState => _currentState;

  void updateCalibration(CalibrationData calibration) {
    if (calibration.calibrated) {
      config.earThreshold = calibration.computeThreshold();
      debugPrint('Updated EAR threshold to: ${config.earThreshold}');
    }
  }

  DrowsinessState processFrame(FaceAnalysisResult faceResult) {
    DriverStatus status = DriverStatus.safe;
    AlertReason alertReason = AlertReason.none;
    String statusMessage = 'SAFE';
    bool drowsy = false;
    bool distracted = false;

    final double ear = faceResult.averageEAR ?? 0.0;
    final double mar = faceResult.mar ?? 0.0;

    if (!faceResult.faceDetected) {
      // No face detected
      _closedHistory.addLast(false);
      _eyeClosedFrames = 0;
      _yawnFrames = 0;
      _pitchDownFrames = 0;
      
      distracted = true;
      alertReason = AlertReason.noFaceDetected;
      statusMessage = 'FACE NOT DETECTED';
    } else {
      // Check eyes closed
      final bool eyesClosed = ear < config.earThreshold;
      _closedHistory.addLast(eyesClosed);
      
      // Maintain window size
      while (_closedHistory.length > config.perclosWindow) {
        _closedHistory.removeFirst();
      }

      if (eyesClosed) {
        _eyeClosedFrames++;
      } else {
        _eyeClosedFrames = 0;
      }

      // Calculate PERCLOS
      final int closedCount = _closedHistory.where((e) => e).length;
      final double perclos = closedCount / _closedHistory.length.clamp(1, config.perclosWindow);

      // Check drowsiness conditions
      if (_eyeClosedFrames >= config.earConsecFrames) {
        drowsy = true;
        alertReason = AlertReason.eyesClosed;
        statusMessage = 'EYES CLOSED TOO LONG!';
      } else if (perclos >= config.perclosThreshold) {
        drowsy = true;
        alertReason = AlertReason.perclosHigh;
        statusMessage = 'DROWSY (PERCLOS ${(perclos * 100).toInt()}%)';
      }

      // Check yawning
      if (mar > config.marThreshold) {
        _yawnFrames++;
      } else {
        _yawnFrames = 0;
      }

      if (_yawnFrames >= config.yawnConsecFrames) {
        drowsy = true;
        alertReason = AlertReason.yawning;
        statusMessage = 'YAWNING!';
      }

      // Check head pose
      final headPitch = faceResult.headEulerAngleX;
      final headYaw = faceResult.headEulerAngleY;

      if (headPitch != null && headPitch < -config.pitchDownThreshold) {
        _pitchDownFrames++;
      } else {
        _pitchDownFrames = 0;
      }

      if (_pitchDownFrames >= config.pitchDownConsecFrames) {
        drowsy = true;
        alertReason = AlertReason.headDown;
        statusMessage = 'HEAD DOWN!';
      }

      if (headYaw != null && headYaw.abs() >= config.yawAbsThreshold) {
        distracted = true;
        alertReason = AlertReason.lookingAway;
        statusMessage = 'LOOKING AWAY';
      }

      // Update state with PERCLOS
      _currentState = _currentState.copyWith(perclos: perclos);
    }

    // Determine final status
    if (drowsy && distracted) {
      status = DriverStatus.danger;
    } else if (drowsy) {
      status = DriverStatus.drowsy;
    } else if (distracted) {
      status = DriverStatus.distracted;
    } else {
      status = DriverStatus.safe;
      if (faceResult.faceDetected) {
        statusMessage = 'SAFE (EAR: ${ear.toStringAsFixed(2)})';
      }
    }

    _currentState = DrowsinessState(
      status: status,
      alertReason: alertReason,
      ear: ear,
      mar: mar,
      perclos: _currentState.perclos,
      headPitch: faceResult.headEulerAngleX,
      headYaw: faceResult.headEulerAngleY,
      headRoll: faceResult.headEulerAngleZ,
      eyeClosedFrames: _eyeClosedFrames,
      yawnFrames: _yawnFrames,
      headDownFrames: _pitchDownFrames,
      faceDetected: faceResult.faceDetected,
      statusMessage: statusMessage,
    );

    // Trigger callbacks
    onStateChanged?.call(_currentState);
    
    if (alertReason != AlertReason.none) {
      final String alertMessage = _getAlertMessage(alertReason);
      onAlert?.call(alertReason, alertMessage);
    }

    return _currentState;
  }

  String _getAlertMessage(AlertReason reason) {
    switch (reason) {
      case AlertReason.eyesClosed:
        return 'Warning! Your eyes have been closed too long. Stay focused!';
      case AlertReason.perclosHigh:
        return 'You look drowsy. Please take a short break.';
      case AlertReason.yawning:
        return 'You are yawning. Are you getting sleepy?';
      case AlertReason.headDown:
        return 'Your head is down. Keep your eyes on the road!';
      case AlertReason.lookingAway:
        return 'Please watch the road ahead.';
      case AlertReason.noFaceDetected:
        return 'Face not detected. Make sure the camera can see your face.';
      case AlertReason.phonDetected:
        return 'Phone detected! Put your phone away.';
      default:
        return '';
    }
  }

  void reset() {
    _closedHistory.clear();
    _eyeClosedFrames = 0;
    _yawnFrames = 0;
    _pitchDownFrames = 0;
    _currentState = DrowsinessState();
  }
}
