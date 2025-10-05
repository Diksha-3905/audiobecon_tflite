import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../inference_benchmark.dart';

class TFLiteEngine implements InferenceEngine {
  Interpreter? _interpreter;
  int _modelSize = 0;

  @override
  String get name => 'TensorFlow Lite';

  @override
  int get modelSizeBytes => _modelSize;

  @override
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/yamnet.tflite');

      final file = File('assets/yamnet.tflite');
      if (await file.exists()) {
        _modelSize = await file.length();
      }

      debugPrint('TFLite model loaded successfully');
    } catch (e) {
      debugPrint('Error loading TFLite model: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> infer(List<double> audioData) async {
    if (_interpreter == null) {
      throw Exception('Interpreter not initialized');
    }

    final input = audioData.reshape([1, audioData.length]);
    final output = List.filled(1 * 521, 0.0).reshape([1, 521]);

    _interpreter!.run(input, output);

    final scores = output[0] as List<double>;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);

    return {
      'class_index': maxIndex,
      'confidence': maxScore,
      'all_scores': scores,
    };
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}

extension on List<double> {
  List<List<double>> reshape(List<int> shape) {
    if (shape.length != 2) {
      throw ArgumentError('Only 2D reshape supported');
    }

    final result = <List<double>>[];
    for (int i = 0; i < shape[0]; i++) {
      final row = <double>[];
      for (int j = 0; j < shape[1]; j++) {
        row.add(this[i * shape[1] + j]);
      }
      result.add(row);
    }
    return result;
  }
}
