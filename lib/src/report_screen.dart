import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'tracker.dart';

/// Sorting modes for the report screen list.
enum PerflutterSort {
  /// Newest screens first.
  latest,
  /// Highest dropped-frame rate first.
  lowPerformance,
  /// Aggregate and sort by visit count.
  collect
}

/// Full-screen report UI that displays collected performance metrics.
class PerflutterReportScreen extends StatefulWidget {
  /// Called when the report should be closed.
  final VoidCallback? onClose;
  /// Creates a report screen.
  const PerflutterReportScreen({super.key, this.onClose});

  @override
  State<PerflutterReportScreen> createState() => _PerflutterReportScreenState();
}

class _PerflutterReportScreenState extends State<PerflutterReportScreen> {
  PerflutterSort _currentSort = PerflutterSort.latest;
  String _deviceDetails = 'Fetching device info...';
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    var details = '';
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        details = '${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        details = '${iosInfo.name} (${iosInfo.systemName} ${iosInfo.systemVersion})';
      }
    } catch (e) {
      details = 'Device Info Unavailable';
    }
    if (mounted) setState(() => _deviceDetails = details);
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes} min ${duration.inSeconds % 60} sec';
    } else {
      return '${duration.inSeconds} sec';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PerflutterTracker.instance,
      builder: (context, _) {
        final tracker = PerflutterTracker.instance;
        final history = tracker.history; 
        final current = tracker.currentScreen;
        
        // Aggregate history and current screen for a unified unique-per-screen view
        List<ScreenPerformanceData> historyWithCurrent;
        if (current != null) {
          final existingIndex = history.indexWhere((s) => s.screenName == current.screenName);
          if (existingIndex != -1) {
            final aggregated = history[existingIndex].aggregate(current);
            historyWithCurrent = List.from(history);
            historyWithCurrent.removeAt(existingIndex);
            historyWithCurrent.add(aggregated);
          } else {
            historyWithCurrent = [...history, current];
          }
        } else {
          historyWithCurrent = history;
        }

        final totalSessionDuration = DateTime.now().difference(tracker.sessionStartTime);

        // Aggregated Session Data
        var totalFrames = 0;
        var totalDroppedFrames = 0;
        double maxMemory = 0;
        for (final data in historyWithCurrent) {
          totalFrames += data.totalFrames;
          totalDroppedFrames += data.droppedFrames;
          maxMemory = max(maxMemory, data.peakMemoryMb);
        }
        final overallDropRate = totalFrames > 0 ? (totalDroppedFrames / totalFrames * 100) : 0.0;

        // Apply Sorting
        var displayedHistory = <ScreenPerformanceData>[];
        if (_currentSort == PerflutterSort.collect || _currentSort == PerflutterSort.latest) {
          // Both are now naturally aggregated; collect sorts by visits, latest by recency (the list order)
          displayedHistory = historyWithCurrent.reversed.toList();
          if (_currentSort == PerflutterSort.collect) {
            displayedHistory.sort((a, b) => b.visitCount.compareTo(a.visitCount));
          }
        } else if (_currentSort == PerflutterSort.lowPerformance) {
          displayedHistory = List.from(historyWithCurrent);
          displayedHistory.sort((a, b) => (b.droppedFrames / max(1, b.totalFrames)).compareTo(a.droppedFrames / max(1, a.totalFrames)));
        }

        return Directionality(
          textDirection: TextDirection.ltr,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF0F7FF),
              appBar: AppBar(
                backgroundColor: const Color(0xFF2C6BA4),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
            title: const Text(
              'PerFlutter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => tracker.reset(),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showSettingsDialog,
              ),
            ],
          ),
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildOverallSummary(
                    totalSessionDuration,
                    totalFrames,
                    totalDroppedFrames,
                    maxMemory,
                    overallDropRate,
                    history.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('SORT BY:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(width: 8),
                        _buildSortChip('Latest', PerflutterSort.latest),
                        const SizedBox(width: 8),
                        _buildSortChip('Low Perf', PerflutterSort.lowPerformance),
                        const SizedBox(width: 8),
                        _buildSortChip('Collect', PerflutterSort.collect),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = displayedHistory[index];
                      return _buildScreenCard(data);
                    },
                    childCount: displayedHistory.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildDeviceInfo(),
                      _buildJourney(tracker.journey),
                    ],
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
          ), 
        );
      }
    );
  }

  Widget _buildSortChip(String label, PerflutterSort sort) {
    final isSelected = _currentSort == sort;
    return GestureDetector(
      onTap: () => setState(() => _currentSort = sort),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C6BA4) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFF2C6BA4) : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final tracker = PerflutterTracker.instance;
            return AlertDialog(
              title: const Text('Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trigger Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  RadioGroup<PerflutterTriggerMode>(
                    groupValue: tracker.triggerMode,
                    onChanged: (value) {
                      if (value == null) return;
                      tracker.triggerMode = value;
                      setState(() {});
                    },
                    child: const Column(
                      children: [
                        RadioListTile<PerflutterTriggerMode>(
                          title: Text('Floating Button'),
                          value: PerflutterTriggerMode.floatingButton,
                        ),
                        RadioListTile<PerflutterTriggerMode>(
                          title: Text('Long Press'),
                          subtitle: Text('Long press anywhere to open'),
                          value: PerflutterTriggerMode.longPress,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DEVICE SYSTEM INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            'Device: $_deviceDetails',
            style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  Widget _buildJourney(List<String> journey) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('JOURNEY BREADCRUMB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: journey.asMap().entries.map((entry) {
              final idx = entry.key;
              final name = entry.value;
              return Text(
                idx < journey.length - 1 ? '$name ›' : name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF2C6BA4)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSummary(Duration duration, int frames, int dropped, double memory, double dropRate, int screenCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2C6BA4).withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Session Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C6BA4))),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSummaryItem('Session Time', _formatDuration(duration), Icons.timer_outlined),
              _buildSummaryItem('Total Screen Visits', screenCount.toString(), Icons.layers_outlined),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricColumn('Frames Health', '${(100 - dropRate).toStringAsFixed(1)}%', _getPerformanceColor(dropRate)),
              _buildMetricColumn('Total Frames', frames.toString(), const Color(0xFF2C6BA4)),
              _buildMetricColumn('Dropped Frames', dropped.toString(), _getPerformanceColor(dropRate)),
            ],
          ),
          const Divider(height: 32),
          _buildMetricColumn('Max Memory', '${memory.toStringAsFixed(1)} MB', _getMemoryColor(memory)),

        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2C6BA4).withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }


  Widget _buildScreenCard(ScreenPerformanceData data) {
    final dropRate = data.totalFrames > 0 ? (data.droppedFrames / data.totalFrames * 100) : 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            Expanded(child: Text(data.screenName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2C6BA4)))),
             if (_currentSort == PerflutterSort.collect)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF2C6BA4).withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('x${data.visitCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2C6BA4))),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(_formatDuration(data.duration), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            Icon(Icons.bolt, size: 14, color: _getPerformanceColor(dropRate)),
            Text(' ${dropRate.toStringAsFixed(1)}%', 
              style: TextStyle(fontSize: 11, color: _getPerformanceColor(dropRate), fontWeight: FontWeight.bold)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMetricRow('Total Frames', data.totalFrames.toString()),
                _buildMetricRow('Dropped Frames', data.droppedFrames.toString(), color: _getPerformanceColor(dropRate)),
                _buildMetricRow('Peak Memory', '${data.peakMemoryMb.toStringAsFixed(1)} MB', color: _getMemoryColor(data.peakMemoryMb)),
                if (_currentSort == PerflutterSort.collect)
                  _buildMetricRow('Total Visits', data.visitCount.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Color _getPerformanceColor(double dropRate) {
    if (dropRate < 5) return Colors.green;
    if (dropRate < 15) return Colors.orange;
    return Colors.red;
  }

  Color _getMemoryColor(double memoryMb) {
    if (memoryMb < 350) return Colors.green;
    if (memoryMb < 600) return Colors.orange;
    return Colors.red;
  }
}
