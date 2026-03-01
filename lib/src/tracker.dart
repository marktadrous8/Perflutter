import 'dart:io';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The activation mode used to open the performance report overlay.
enum PerflutterTriggerMode {
  /// Shows a draggable floating action button.
  floatingButton, // Shows a FAB on top of the screen
  /// Opens the report when the user long-presses on screen.
  longPress,      // Hidden, triggered by long press anywhere (if not consumed)
}

/// Aggregated performance metrics collected for a single screen.
class ScreenPerformanceData {
  /// Route or screen name.
  final String screenName;
  /// Timestamp when this screen record started.
  final DateTime startTime;
  /// Timestamp when this screen record ended.
  DateTime? endTime;
  /// Total frames rendered while this screen was active.
  int totalFrames = 0;
  /// Frames where UI or Raster time exceeded the frame budget.
  int droppedFrames = 0;
  /// Peak process memory usage in MB captured for this screen.
  double peakMemoryMb = 0;
  /// Number of visits included in this record.
  int visitCount = 1;
  Duration? _accumulatedDuration;

  /// Creates a record for [screenName] and starts timing immediately.
  ScreenPerformanceData(this.screenName) : startTime = DateTime.now();

  /// Elapsed time for this screen visit or aggregated visits.
  Duration get duration => _accumulatedDuration ?? (endTime ?? DateTime.now()).difference(startTime);

  /// Records a frame timing sample.
  void recordFrame(FrameTiming timing, int frameBudgetMicros) {
    totalFrames++;
    final uiMicros = timing.buildDuration.inMicroseconds;
    final rasterMicros = timing.rasterDuration.inMicroseconds;
    if (uiMicros > frameBudgetMicros || rasterMicros > frameBudgetMicros) {
      droppedFrames++;
    }
  }

  /// Combines this record with another visit of the same screen.
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

/// Core tracker that stores session metrics and notifies listeners.
class PerflutterTracker extends ChangeNotifier with WidgetsBindingObserver {
  /// Singleton tracker instance used by package widgets.
  static final PerflutterTracker instance = PerflutterTracker._internal();
  
  /// Session start timestamp.
  DateTime sessionStartTime;
  /// Ordered route history for the current session.
  final List<String> journey = [];
  /// Completed screen performance snapshots.
  List<ScreenPerformanceData> history = [];

  PerflutterTracker._internal() : sessionStartTime = DateTime.now() {
    _initFrameCallback();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _enabled = true;
  bool _reportOverlayActive = false;
  bool _collectEnabled = false;
  /// Whether tracking and observer processing are active.
  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) {return;}
    _enabled = value;
    if (!_enabled) {_currentScreen = null;}
    notifyListeners();
  }

  /// Whether the Perflutter report overlay is currently visible.
  bool get reportOverlayActive => _reportOverlayActive;

  /// Whether report screen displays collected (aggregated) entries.
  bool get collectEnabled => _collectEnabled;

  /// Tracks report overlay visibility without pausing frame collection.
  void setReportOverlayActive(bool value) {
    _reportOverlayActive = value;
  }

  /// Stores collect chip state for the current app session.
  void setCollectEnabled(bool value) {
    _collectEnabled = value;
  }

  PerflutterTriggerMode _triggerMode = PerflutterTriggerMode.floatingButton;
  /// Current trigger mode used by [PerflutterTrigger].
  PerflutterTriggerMode get triggerMode => _triggerMode;

  set triggerMode(PerflutterTriggerMode mode) {
    if (_triggerMode != mode) {
      _triggerMode = mode;
      notifyListeners();
    }
  }

  ScreenPerformanceData? _currentScreen;
  /// Screen currently being tracked.
  ScreenPerformanceData? get currentScreen => _currentScreen;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) {return;}
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
      if (!_enabled || _currentScreen == null) {return;}
      final frameBudgetMicros = _frameBudgetMicros();
        for (final timing in timings) {
          _currentScreen!.recordFrame(timing, frameBudgetMicros);
      }
    });
  }

  int _frameBudgetMicros() {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        final refreshRate = views.first.display.refreshRate;
        if (refreshRate > 0) {
          return (1000000 / refreshRate).round();
        }
      }
    } catch (_) {
      // Fall back to a 60Hz budget if platform data is unavailable.
    }
    return 16666;
  }

  /// Registers a route transition with optional pop semantics.
  void onScreenChanged(String? screenName, {bool isPop = false}) {
    if (!_enabled) {return;}
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

    journey.add(screenName);

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

  /// Clears journey/history and starts a fresh tracking session.
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
