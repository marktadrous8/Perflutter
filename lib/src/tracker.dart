import 'dart:io';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

enum PerflutterTriggerMode {
  floatingButton, // Shows a FAB on top of the screen
  longPress,      // Hidden, triggered by long press anywhere (if not consumed)
}

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

class PerflutterTracker extends ChangeNotifier with WidgetsBindingObserver {
  static final PerflutterTracker instance = PerflutterTracker._internal();
  
  DateTime sessionStartTime;
  final List<String> journey = [];
  List<ScreenPerformanceData> history = [];

  PerflutterTracker._internal() : sessionStartTime = DateTime.now() {
    _initFrameCallback();
    WidgetsBinding.instance.addObserver(this);
  }

  PerflutterTriggerMode _triggerMode = PerflutterTriggerMode.floatingButton;
  PerflutterTriggerMode get triggerMode => _triggerMode;

  set triggerMode(PerflutterTriggerMode mode) {
    if (_triggerMode != mode) {
      _triggerMode = mode;
      notifyListeners();
    }
  }

  ScreenPerformanceData? _currentScreen;
  ScreenPerformanceData? get currentScreen => _currentScreen;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_currentScreen != null) {
        _currentScreen!.endTime = DateTime.now();
        _currentScreen!.peakMemoryMb = _getProcessMemoryMb();
        history = [...history, _currentScreen!];
        _currentScreen = null;
        notifyListeners();
      }
    }
  }

  void _initFrameCallback() {
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      if (_currentScreen != null) {
        for (final timing in timings) {
          _currentScreen!.recordFrame(timing);
        }
      }
    });
  }

  void onScreenChanged(String? screenName, {bool isPop = false}) {
    final isIgnored = screenName == null || 
        screenName == "PerflutterReportScreen" || 
        screenName == "MainRoute" ||
        screenName == "/";

    if (!isPop && isIgnored) {
      return;
    }

    if (isPop && _currentScreen != null && _currentScreen!.screenName == screenName) {
      return;
    }

    if (_currentScreen != null) {
      _currentScreen!.endTime = DateTime.now();
      _currentScreen!.peakMemoryMb = _getProcessMemoryMb();
      history = [...history, _currentScreen!];
      _currentScreen = null;
      notifyListeners();
    }

    if (isIgnored) return;

    journey.add(screenName!);

    _currentScreen = ScreenPerformanceData(screenName);
    _currentScreen!.peakMemoryMb = _getProcessMemoryMb();
    notifyListeners();
  }

  double _getProcessMemoryMb() {
    try {
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (e) {
      return 0;
    }
  }

  void reset() {
    sessionStartTime = DateTime.now();
    journey.clear();
    history = [];
    if (_currentScreen != null) {
      _currentScreen = ScreenPerformanceData(_currentScreen!.screenName);
    }
    notifyListeners();
  }
}
