import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drowsiness_detector_service.dart';

class StorageService {
  static const String _calibrationKey = 'calibration_data';
  static const String _settingsKey = 'app_settings';
  static const String _sessionHistoryKey = 'session_history';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // Calibration Data
  Future<void> saveCalibration(CalibrationData data) async {
    if (!_isInitialized) await initialize();
    final json = jsonEncode(data.toJson());
    await _prefs.setString(_calibrationKey, json);
    debugPrint('Calibration data saved');
  }

  Future<CalibrationData> loadCalibration() async {
    if (!_isInitialized) await initialize();
    final json = _prefs.getString(_calibrationKey);
    if (json == null) {
      return CalibrationData();
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CalibrationData.fromJson(map);
    } catch (e) {
      debugPrint('Error loading calibration: $e');
      return CalibrationData();
    }
  }

  // App Settings
  Future<void> saveSettings(AppSettings settings) async {
    if (!_isInitialized) await initialize();
    final json = jsonEncode(settings.toJson());
    await _prefs.setString(_settingsKey, json);
  }

  Future<AppSettings> loadSettings() async {
    if (!_isInitialized) await initialize();
    final json = _prefs.getString(_settingsKey);
    if (json == null) {
      return AppSettings();
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return AppSettings();
    }
  }

  // Session History
  Future<void> saveSession(SessionData session) async {
    if (!_isInitialized) await initialize();
    
    final history = await loadSessionHistory();
    history.add(session);
    
    // Keep only last 100 sessions
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }
    
    final json = jsonEncode(history.map((s) => s.toJson()).toList());
    await _prefs.setString(_sessionHistoryKey, json);
  }

  Future<List<SessionData>> loadSessionHistory() async {
    if (!_isInitialized) await initialize();
    final json = _prefs.getString(_sessionHistoryKey);
    if (json == null) return [];
    
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => SessionData.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading session history: $e');
      return [];
    }
  }

  Future<void> clearAll() async {
    if (!_isInitialized) await initialize();
    await _prefs.clear();
  }
}

class AppSettings {

  AppSettings({
    this.ttsEnabled = true,
    this.vibrationEnabled = true,
    this.showDebugInfo = true,
    this.showFaceMesh = true,
    this.ttsCooldown = 5.0,
    this.targetFps = 30,
    this.earThreshold = 0.21,
    this.marThreshold = 0.55,
    this.yawThreshold = 25.0,
    this.pitchThreshold = 10.0,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      ttsEnabled: json['ttsEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      showDebugInfo: json['showDebugInfo'] as bool? ?? true,
      showFaceMesh: json['showFaceMesh'] as bool? ?? true,
      ttsCooldown: (json['ttsCooldown'] as num?)?.toDouble() ?? 5.0,
      targetFps: json['targetFps'] as int? ?? 30,
      earThreshold: (json['earThreshold'] as num?)?.toDouble() ?? 0.21,
      marThreshold: (json['marThreshold'] as num?)?.toDouble() ?? 0.55,
      yawThreshold: (json['yawThreshold'] as num?)?.toDouble() ?? 25.0,
      pitchThreshold: (json['pitchThreshold'] as num?)?.toDouble() ?? 10.0,
    );
  }
  final bool ttsEnabled;
  final bool vibrationEnabled;
  final bool showDebugInfo;
  final bool showFaceMesh;
  final double ttsCooldown;
  final int targetFps;
  final double earThreshold;
  final double marThreshold;
  final double yawThreshold;
  final double pitchThreshold;

  Map<String, dynamic> toJson() => {
    'ttsEnabled': ttsEnabled,
    'vibrationEnabled': vibrationEnabled,
    'showDebugInfo': showDebugInfo,
    'showFaceMesh': showFaceMesh,
    'ttsCooldown': ttsCooldown,
    'targetFps': targetFps,
    'earThreshold': earThreshold,
    'marThreshold': marThreshold,
    'yawThreshold': yawThreshold,
    'pitchThreshold': pitchThreshold,
  };

  AppSettings copyWith({
    bool? ttsEnabled,
    bool? vibrationEnabled,
    bool? showDebugInfo,
    bool? showFaceMesh,
    double? ttsCooldown,
    int? targetFps,
    double? earThreshold,
    double? marThreshold,
    double? yawThreshold,
    double? pitchThreshold,
  }) {
    return AppSettings(
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      showFaceMesh: showFaceMesh ?? this.showFaceMesh,
      ttsCooldown: ttsCooldown ?? this.ttsCooldown,
      targetFps: targetFps ?? this.targetFps,
      earThreshold: earThreshold ?? this.earThreshold,
      marThreshold: marThreshold ?? this.marThreshold,
      yawThreshold: yawThreshold ?? this.yawThreshold,
      pitchThreshold: pitchThreshold ?? this.pitchThreshold,
    );
  }
}

class SessionData {

  SessionData({
    required this.startTime,
    required this.endTime,
    this.totalFrames = 0,
    this.drowsyFrames = 0,
    this.distractedFrames = 0,
    this.alertCount = 0,
    this.averageEAR = 0.0,
    this.maxPerclos = 0.0,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      totalFrames: json['totalFrames'] as int? ?? 0,
      drowsyFrames: json['drowsyFrames'] as int? ?? 0,
      distractedFrames: json['distractedFrames'] as int? ?? 0,
      alertCount: json['alertCount'] as int? ?? 0,
      averageEAR: (json['averageEAR'] as num?)?.toDouble() ?? 0.0,
      maxPerclos: (json['maxPerclos'] as num?)?.toDouble() ?? 0.0,
    );
  }
  final DateTime startTime;
  final DateTime endTime;
  final int totalFrames;
  final int drowsyFrames;
  final int distractedFrames;
  final int alertCount;
  final double averageEAR;
  final double maxPerclos;

  Duration get duration => endTime.difference(startTime);

  double get drowsinessPercentage {
    if (totalFrames == 0) return 0.0;
    return (drowsyFrames / totalFrames) * 100;
  }

  double get distractionPercentage {
    if (totalFrames == 0) return 0.0;
    return (distractedFrames / totalFrames) * 100;
  }

  double get safetyScore {
    if (totalFrames == 0) return 100.0;
    final unsafeFrames = drowsyFrames + distractedFrames;
    return ((totalFrames - unsafeFrames) / totalFrames) * 100;
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'totalFrames': totalFrames,
    'drowsyFrames': drowsyFrames,
    'distractedFrames': distractedFrames,
    'alertCount': alertCount,
    'averageEAR': averageEAR,
    'maxPerclos': maxPerclos,
  };
}
