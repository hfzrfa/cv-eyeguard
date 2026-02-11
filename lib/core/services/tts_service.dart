import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'drowsiness_detector_service.dart';

class TTSService {

  TTSService({this.cooldown = const Duration(seconds: 5)});
  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, DateTime> _lastSpeakTime = {};
  final Duration cooldown;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set language to English
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
      });

      _isInitialized = true;
      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> speak(String text, {String category = 'default'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check cooldown
    final now = DateTime.now();
    final lastTime = _lastSpeakTime[category];
    if (lastTime != null && now.difference(lastTime) < cooldown) {
      return;
    }

    _lastSpeakTime[category] = now;

    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> speakAlert(AlertReason reason) async {
    String message;
    String category;

    switch (reason) {
      case AlertReason.eyesClosed:
        message = 'Warning! Your eyes have been closed too long. Stay focused!';
        category = 'drowsy';
        break;
      case AlertReason.perclosHigh:
        message = 'You look drowsy. Please take a short break.';
        category = 'drowsy';
        break;
      case AlertReason.yawning:
        message = 'You are yawning. Are you getting sleepy?';
        category = 'yawn';
        break;
      case AlertReason.headDown:
        message = 'Your head is down. Keep your eyes on the road!';
        category = 'head';
        break;
      case AlertReason.lookingAway:
        message = 'Please watch the road ahead.';
        category = 'looking';
        break;
      case AlertReason.noFaceDetected:
        message = 'Face not detected.';
        category = 'face';
        break;
      case AlertReason.phonDetected:
        message = 'Distraction detected. Put your phone away!';
        category = 'phone';
        break;
      default:
        return;
    }

    await speak(message, category: category);
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}
