import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerformanceMonitorService {
  static final PerformanceMonitorService instance =
      PerformanceMonitorService._();

  PerformanceMonitorService._();

  bool _started = false;
  DateTime _lastFrameLog = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _gpsWindowStart = DateTime.now();
  int _gpsSamples = 0;
  int _frameSamples = 0;
  int _jankyFrames = 0;
  double _averageFrameMs = 0;

  double gpsHz = 0;
  int? lastBleLatencyMs;
  int? lastRouteLatencyMs;

  void start() {
    if (_started) return;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _started = true;
  }

  void stop() {
    if (!_started) return;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _started = false;
  }

  void recordGpsSample() {
    _gpsSamples++;
    final now = DateTime.now();
    final elapsed = now.difference(_gpsWindowStart);
    if (elapsed < const Duration(seconds: 3)) return;

    gpsHz = _gpsSamples / (elapsed.inMilliseconds / 1000);
    _gpsSamples = 0;
    _gpsWindowStart = now;
  }

  void recordBleWrite(Duration latency) {
    lastBleLatencyMs = latency.inMilliseconds;
    if (latency > const Duration(milliseconds: 200)) {
      debugPrint('BLE latency warning: ${latency.inMilliseconds} ms');
    }
  }

  void recordRouteCalculation(Duration latency) {
    lastRouteLatencyMs = latency.inMilliseconds;
    if (latency > const Duration(seconds: 3)) {
      debugPrint('Route calculation warning: ${latency.inMilliseconds} ms');
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;

    var totalMs = 0.0;
    for (final timing in timings) {
      final frameMs =
          (timing.buildDuration.inMicroseconds +
                  timing.rasterDuration.inMicroseconds) /
              1000;
      totalMs += frameMs;
      if (frameMs > 20) _jankyFrames++;
    }
    _frameSamples += timings.length;
    final batchAverage = totalMs / timings.length;
    _averageFrameMs = _averageFrameMs == 0
        ? batchAverage
        : (_averageFrameMs * 0.85) + (batchAverage * 0.15);

    final now = DateTime.now();
    if (now.difference(_lastFrameLog) < const Duration(seconds: 8)) return;
    _lastFrameLog = now;
    if (_frameSamples == 0) return;

    final jankPercent = (_jankyFrames / _frameSamples) * 100;
    debugPrint(
      'Frame diag: ${_averageFrameMs.toStringAsFixed(1)} ms avg, '
      '${jankPercent.toStringAsFixed(1)}% janky, '
      'GPS ${gpsHz.toStringAsFixed(1)} Hz, '
      'BLE ${lastBleLatencyMs ?? 0} ms, '
      'route ${lastRouteLatencyMs ?? 0} ms',
    );

    _frameSamples = 0;
    _jankyFrames = 0;
  }
}
