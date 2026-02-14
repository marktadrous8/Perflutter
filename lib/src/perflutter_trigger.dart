import 'package:flutter/material.dart';
import 'report_screen.dart';
import 'tracker.dart';

/// Wraps app content and provides entry points to the performance report.
class PerflutterTrigger extends StatefulWidget {
  /// Root app widget.
  final Widget child;
  /// Enables/disables report trigger behavior.
  final bool enabled;
  // triggerMode is now handled by the PerflutterTracker singleton, 
  // but we keep this parameter name for backward compatibility.
  /// Optional initial trigger mode.
  final PerflutterTriggerMode? triggerMode; 

  /// Creates the trigger wrapper.
  const PerflutterTrigger({
    super.key,
    required this.child,
    this.enabled = true,
    this.triggerMode,
  });

  @override
  State<PerflutterTrigger> createState() => _PerflutterTriggerState();
}

class _PerflutterTriggerState extends State<PerflutterTrigger> {
  bool _showReport = false;

  Offset? _fabPosition;

  @override
  void initState() {
    super.initState();
    if (widget.triggerMode != null) {
      PerflutterTracker.instance.triggerMode = widget.triggerMode!;
    }
    // Listen to changes in trigger mode
    PerflutterTracker.instance.addListener(_handleTrackerUpdate);
  }

  @override
  void dispose() {
    PerflutterTracker.instance.removeListener(_handleTrackerUpdate);
    super.dispose();
  }

  void _handleTrackerUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleReport() {
    setState(() {
      _showReport = !_showReport;
    });
  }

  void _closeReport() {
    setState(() {
      _showReport = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // Read the current mode from the tracker
    final currentMode = PerflutterTracker.instance.triggerMode;

    final content = Directionality(
      textDirection: TextDirection.ltr,
      child: widget.child,
    );
    
    final isFloatingMode = currentMode == PerflutterTriggerMode.floatingButton;
    final isLongPressMode = currentMode == PerflutterTriggerMode.longPress;

    // Calculate default position only when floating mode is enabled
    if (isFloatingMode && _fabPosition == null) {
      final size = MediaQuery.of(context).size;
      if (!size.isEmpty) {
         // Default to bottom right: right: 16, bottom: 100
         // FAB (mini) is approx 40 + padding ~48
         _fabPosition = Offset(size.width - 16 - 48, size.height - 100 - 48);
      } else {
         // Fallback for release mode if size is not yet ready
         _fabPosition = const Offset(20, 100);
         
         // Try to correct it after the frame
         WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.mounted) {
               final newSize = MediaQuery.of(context).size;
               if (!newSize.isEmpty) {
                 setState(() {
                   _fabPosition = Offset(newSize.width - 16 - 48, newSize.height - 100 - 48);
                 });
               }
            }
         });
      }
    }

    // We build a Stack where the report screen sits on top of the app content
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // 1. The App Content wrapped in Persistent Gesture Detector
          // This allows Long Press to work without blocking the app (translucent)
          // And ensures the tree structure is stable (no reparenting crashes)
          GestureDetector(
            onLongPress: isLongPressMode ? _toggleReport : null,
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            child: content,
          ),

          // 2. The Floating Button
          if (!_showReport && isFloatingMode && _fabPosition != null)
            Positioned(
              left: _fabPosition!.dx,
              top: _fabPosition!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _fabPosition = _fabPosition! + details.delta;
                  });
                },
                child: SafeArea(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Opacity(
                      opacity: 0.5, 
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'perflutter_trigger',
                        backgroundColor: const Color(0xFF2C6BA4),
                        onPressed: _toggleReport,
                        child: const Icon(Icons.show_chart, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3. The Report Screen
          if (_showReport)
            Positioned.fill(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: PerflutterReportScreen(
                  onClose: _closeReport,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
