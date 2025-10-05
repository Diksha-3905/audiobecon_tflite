import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class InferenceEngine {
  String get name;
  Future<void> initialize();
  Future<Map<String, dynamic>> infer(List<double> audioData);
  Future<void> dispose();
  int get modelSizeBytes;
}

class BenchmarkResult {
  final String engineName;
  final double avgInferenceTimeMs;
  final double minInferenceTimeMs;
  final double maxInferenceTimeMs;
  final double stdDeviation;
  final int modelSizeBytes;
  final double memoryUsageMB;
  final int totalRuns;
  final DateTime timestamp;

  BenchmarkResult({
    required this.engineName,
    required this.avgInferenceTimeMs,
    required this.minInferenceTimeMs,
    required this.maxInferenceTimeMs,
    required this.stdDeviation,
    required this.modelSizeBytes,
    required this.memoryUsageMB,
    required this.totalRuns,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'engineName': engineName,
        'avgInferenceTimeMs': avgInferenceTimeMs,
        'minInferenceTimeMs': minInferenceTimeMs,
        'maxInferenceTimeMs': maxInferenceTimeMs,
        'stdDeviation': stdDeviation,
        'modelSizeBytes': modelSizeBytes,
        'memoryUsageMB': memoryUsageMB,
        'totalRuns': totalRuns,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() {
    return '''
    Engine: $engineName
    Avg Inference Time: ${avgInferenceTimeMs.toStringAsFixed(2)} ms
    Min/Max: ${minInferenceTimeMs.toStringAsFixed(2)} / ${maxInferenceTimeMs.toStringAsFixed(2)} ms
    Std Deviation: ${stdDeviation.toStringAsFixed(2)} ms
    Model Size: ${(modelSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB
    Memory Usage: ${memoryUsageMB.toStringAsFixed(2)} MB
    Total Runs: $totalRuns
    ''';
  }
}

class InferenceBenchmark {
  final InferenceEngine engine;
  final int warmupRuns;
  final int benchmarkRuns;

  InferenceBenchmark({
    required this.engine,
    this.warmupRuns = 10,
    this.benchmarkRuns = 100,
  });

  Future<BenchmarkResult> run(List<double> sampleAudioData) async {
    debugPrint('Initializing ${engine.name}...');
    await engine.initialize();

    debugPrint('Running warmup ($warmupRuns runs)...');
    for (int i = 0; i < warmupRuns; i++) {
      await engine.infer(sampleAudioData);
    }

    debugPrint('Running benchmark ($benchmarkRuns runs)...');
    final List<double> inferenceTimes = [];

    for (int i = 0; i < benchmarkRuns; i++) {
      final stopwatch = Stopwatch()..start();
      await engine.infer(sampleAudioData);
      stopwatch.stop();
      inferenceTimes.add(stopwatch.elapsedMicroseconds / 1000.0);
    }

    final avgTime = inferenceTimes.reduce((a, b) => a + b) / inferenceTimes.length;
    final minTime = inferenceTimes.reduce((a, b) => a < b ? a : b);
    final maxTime = inferenceTimes.reduce((a, b) => a > b ? a : b);

    final variance = inferenceTimes
            .map((time) => (time - avgTime) * (time - avgTime))
            .reduce((a, b) => a + b) /
        inferenceTimes.length;
    final stdDev = variance.sqrt();

    final result = BenchmarkResult(
      engineName: engine.name,
      avgInferenceTimeMs: avgTime,
      minInferenceTimeMs: minTime,
      maxInferenceTimeMs: maxTime,
      stdDeviation: stdDev,
      modelSizeBytes: engine.modelSizeBytes,
      memoryUsageMB: 0.0,
      totalRuns: benchmarkRuns,
      timestamp: DateTime.now(),
    );

    await engine.dispose();

    return result;
  }
}

extension on double {
  double sqrt() {
    double x = this;
    double y = 1.0;
    double e = 0.000001;
    while (x - y > e) {
      x = (x + y) / 2;
      y = this / x;
    }
    return x;
  }
}
