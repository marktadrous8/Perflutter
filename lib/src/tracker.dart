import 'dart:io';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScreenPerformanceData {
  final String screenName;
  final DateTime startTime;
  DateTime? endTime;
  int totalFrames = 0;
  int droppedFrames = 0;
  double peakMemoryMb = 0;
  int visitCount = 1;
  Duration? _accumulatedDuration;

  ScreenPerformanceData(this.screenName) : startTime = DateTime.now();

  Duration get duration => _accumulatedDuration ?? (endTime ?? DateTime.now()).difference(startTime);

  void recordFrame(FrameTiming timing) {
    totalFrames++;
    if (timing.totalSpan.inMicroseconds > 16666) {
      droppedFrames++;
    }
  }

  ScreenPerformanceData aggregate(ScreenPerformanceData other) {
    final aggregated = ScreenPerformanceData(screenName);
    aggregated.totalFrames = totalFrames + other.totalFrames;
    aggregated.droppedFrames = droppedFrames + other.droppedFrames;
    aggregated.peakMemoryMb = max(peakMemoryMb, other.peakMemoryMb);
    aggregated.visitCount = visitCount + other.visitCount;
    aggregated._accumulatedDuration = duration + other.duration;
    
    // For sorting/display, use the latest end time
    aggregated.endTime = (endTime != null && other.endTime != null) 
        ? (endTime!.isAfter(other.endTime!) ? endTime : other.endTime)
        : (endTime ?? other.endTime);
    return aggregated;
  }
}

class PerflutterTracker extends StateNotifier<List<ScreenPerformanceData>> {
  DateTime sessionStartTime;
  final List<String> journey = [];
  
  PerflutterTracker() : sessionStartTime = DateTime.now(), super([]) {
    _initFrameCallback();
  }

  ScreenPerformanceData? _currentScreen;

  void _initFrameCallback() {
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      if (_currentScreen != null) {
        for (final timing in timings) {
          _currentScreen!.recordFrame(timing);
        }
      }
    });
  }

  ScreenPerformanceData? get currentScreen => _currentScreen;

  void onScreenChanged(String? screenName, {bool isPop = false}) {
    final isIgnored = screenName == null || 
        screenName == "PerflutterReportScreen" || 
        screenName == "MainRoute" ||
        screenName == "/";

    // 1. If we are pushing an ignored screen (like the report itself),
    // don't stop the current screen. Just return.
    if (!isPop && isIgnored) {
      return;
    }

    // 2. If we are popping back to the SAME screen that is currently active,
    // don't restart. This allows Page A -> Report -> Page A to be one session.
    if (isPop && _currentScreen != null && _currentScreen!.screenName == screenName) {
      return;
    }

    // 3. Otherwise, stop the current session and start a new one.
    if (_currentScreen != null) {
      _currentScreen!.endTime = DateTime.now();
      _currentScreen!.peakMemoryMb = _getProcessMemoryMb();
      state = [...state, _currentScreen!];
      _currentScreen = null;
    }

    if (isIgnored) return;

    // Add to journey
    journey.add(screenName!);

    // Start new screen session
    _currentScreen = ScreenPerformanceData(screenName);
    _currentScreen!.peakMemoryMb = _getProcessMemoryMb();
  }

  double _getProcessMemoryMb() {
    try {
      // Basic memory check - RSS is roughly the amount of memory consumed by the process.
      // Note: This is an approximation.
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (e) {
      return 0;
    }
  }

  List<ScreenPerformanceData> get fullHistory => [...state, if (_currentScreen != null) _currentScreen!];

  void reset() {
    sessionStartTime = DateTime.now();
    journey.clear();
    state = [];
    if (_currentScreen != null) {
      _currentScreen = ScreenPerformanceData(_currentScreen!.screenName);
    }
  }
}

final perflutterTrackerProvider = StateNotifierProvider<PerflutterTracker, List<ScreenPerformanceData>>((ref) {
  return PerflutterTracker();
});
