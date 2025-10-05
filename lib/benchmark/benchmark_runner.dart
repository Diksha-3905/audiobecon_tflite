import 'dart:math';
import 'package:flutter/foundation.dart';
import 'inference_benchmark.dart';
import 'engines/tflite_engine.dart';
import 'engines/onnx_engine.dart';
import 'engines/pytorch_mobile_engine.dart';
import 'engines/coreml_engine.dart';
import 'engines/mediapipe_engine.dart';

class BenchmarkRunner {
  final List<InferenceEngine> engines;
  final int audioSampleLength;
  final int warmupRuns;
  final int benchmarkRuns;

  BenchmarkRunner({
    List<InferenceEngine>? engines,
    this.audioSampleLength = 16000,
    this.warmupRuns = 10,
    this.benchmarkRuns = 100,
  }) : engines = engines ?? _getDefaultEngines();

  static List<InferenceEngine> _getDefaultEngines() {
    return [
      TFLiteEngine(),
      ONNXEngine(),
      PyTorchMobileEngine(),
      MediaPipeEngine(),
    ];
  }

  List<double> generateSampleAudio() {
    final random = Random(42);
    return List.generate(
      audioSampleLength,
      (index) => (random.nextDouble() * 2.0 - 1.0) * 0.5,
    );
  }

  Future<List<BenchmarkResult>> runAll() async {
    final results = <BenchmarkResult>[];
    final sampleAudio = generateSampleAudio();

    debugPrint('=== Starting Benchmark Suite ===');
    debugPrint('Audio sample length: $audioSampleLength');
    debugPrint('Warmup runs: $warmupRuns');
    debugPrint('Benchmark runs: $benchmarkRuns');
    debugPrint('Engines to test: ${engines.length}');
    debugPrint('');

    for (final engine in engines) {
      try {
        debugPrint('--- Testing ${engine.name} ---');

        final benchmark = InferenceBenchmark(
          engine: engine,
          warmupRuns: warmupRuns,
          benchmarkRuns: benchmarkRuns,
        );

        final result = await benchmark.run(sampleAudio);
        results.add(result);

        debugPrint('✓ ${engine.name} completed');
        debugPrint(result.toString());
      } catch (e) {
        debugPrint('✗ ${engine.name} failed: $e');
      }
    }

    debugPrint('=== Benchmark Complete ===');
    _printComparison(results);

    return results;
  }

  void _printComparison(List<BenchmarkResult> results) {
    if (results.isEmpty) {
      debugPrint('No results to compare');
      return;
    }

    debugPrint('\n=== Performance Comparison ===\n');

    results.sort((a, b) => a.avgInferenceTimeMs.compareTo(b.avgInferenceTimeMs));

    final fastest = results.first;
    debugPrint('🏆 Fastest: ${fastest.engineName}');
    debugPrint('   ${fastest.avgInferenceTimeMs.toStringAsFixed(2)} ms\n');

    debugPrint('Ranking by Average Inference Time:');
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final speedup = result.avgInferenceTimeMs / fastest.avgInferenceTimeMs;
      debugPrint(
        '${i + 1}. ${result.engineName.padRight(20)} '
        '${result.avgInferenceTimeMs.toStringAsFixed(2)} ms '
        '(${speedup.toStringAsFixed(2)}x slower)',
      );
    }

    debugPrint('\nModel Size Comparison:');
    results.sort((a, b) => a.modelSizeBytes.compareTo(b.modelSizeBytes));
    for (final result in results) {
      final sizeMB = result.modelSizeBytes / 1024 / 1024;
      debugPrint(
        '  ${result.engineName.padRight(20)} ${sizeMB.toStringAsFixed(2)} MB',
      );
    }

    debugPrint('\nStability (Lower std dev is better):');
    results.sort((a, b) => a.stdDeviation.compareTo(b.stdDeviation));
    for (final result in results) {
      debugPrint(
        '  ${result.engineName.padRight(20)} ±${result.stdDeviation.toStringAsFixed(2)} ms',
      );
    }
  }

  Future<Map<String, dynamic>> generateReport() async {
    final results = await runAll();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'configuration': {
        'audioSampleLength': audioSampleLength,
        'warmupRuns': warmupRuns,
        'benchmarkRuns': benchmarkRuns,
      },
      'results': results.map((r) => r.toJson()).toList(),
      'summary': _generateSummary(results),
    };
  }

  Map<String, dynamic> _generateSummary(List<BenchmarkResult> results) {
    if (results.isEmpty) {
      return {'error': 'No results available'};
    }

    final sortedBySpeed = List<BenchmarkResult>.from(results)
      ..sort((a, b) => a.avgInferenceTimeMs.compareTo(b.avgInferenceTimeMs));

    final sortedBySize = List<BenchmarkResult>.from(results)
      ..sort((a, b) => a.modelSizeBytes.compareTo(b.modelSizeBytes));

    final sortedByStability = List<BenchmarkResult>.from(results)
      ..sort((a, b) => a.stdDeviation.compareTo(b.stdDeviation));

    return {
      'fastest': {
        'engine': sortedBySpeed.first.engineName,
        'time_ms': sortedBySpeed.first.avgInferenceTimeMs,
      },
      'smallest': {
        'engine': sortedBySize.first.engineName,
        'size_mb': sortedBySize.first.modelSizeBytes / 1024 / 1024,
      },
      'most_stable': {
        'engine': sortedByStability.first.engineName,
        'std_dev_ms': sortedByStability.first.stdDeviation,
      },
      'recommendation': _generateRecommendation(results),
    };
  }

  String _generateRecommendation(List<BenchmarkResult> results) {
    final sortedBySpeed = List<BenchmarkResult>.from(results)
      ..sort((a, b) => a.avgInferenceTimeMs.compareTo(b.avgInferenceTimeMs));

    final fastest = sortedBySpeed.first;
    final speedDiff = sortedBySpeed.length > 1
        ? (sortedBySpeed[1].avgInferenceTimeMs - fastest.avgInferenceTimeMs) /
            fastest.avgInferenceTimeMs
        : 0.0;

    if (speedDiff > 0.2) {
      return '${fastest.engineName} is significantly faster (>20% improvement). '
          'Consider switching if cross-platform support is maintained.';
    } else if (speedDiff > 0.1) {
      return '${fastest.engineName} shows moderate improvement (10-20%). '
          'Evaluate trade-offs with implementation complexity.';
    } else {
      return 'Performance differences are minimal (<10%). '
          'Stick with current implementation unless other factors (size, features) are important.';
    }
  }
}
