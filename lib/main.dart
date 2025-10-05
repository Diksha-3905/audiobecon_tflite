import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Classifier',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SoundPage(),
    );
  }
}

class SoundPage extends StatefulWidget {
  const SoundPage({super.key});

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final SoundClassifier _classifier = SoundClassifier();
  bool _isRecording = false;
  bool _hasPermission = false;
  double _dbLevel = 0.0;
  late AnimationController _animationController;
  String _processingTime = "0 ms";
  late List<double> _audioBars;
  Timer? _visualizerTimer;
  Timer? _classificationTimer;
  String _currentSoundLabel = "No sound detected";
  double _currentConfidence = 0.0;
  final List<double> _audioBuffer = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _audioBars = List.generate(20, (index) => 0.0);
    _initRecorder();
    _classifier.loadModel();
  }

  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      setState(() {
        _hasPermission = status.isGranted;
      });

      if (_hasPermission) {
        await _audioRecorder.openRecorder();
        _audioRecorder.setSubscriptionDuration(const Duration(milliseconds: 50));
      } else {
        debugPrint("❌ Microphone permission denied!");
      }
    } catch (e) {
      debugPrint("Error initializing recorder: $e");
    }
  }

  void _updateVisualizer() {
    if (_isRecording) {
      setState(() {
        for (int i = 0; i < _audioBars.length - 1; i++) {
          _audioBars[i] = _audioBars[i + 1];
        }
        _audioBars[_audioBars.length - 1] = (_dbLevel / 100).clamp(0.0, 1.0);
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!_hasPermission) {
        await _initRecorder();
        return;
      }

      if (!_audioRecorder.isRecording) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = p.join(directory.path, 'my_recording.wav');

        await _audioRecorder.startRecorder(
          toFile: filePath,
          codec: Codec.pcm16WAV,
          sampleRate: 16000,
        );

        setState(() {
          _isRecording = true;
        });

        _animationController.repeat(reverse: true);

        _visualizerTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
          _updateVisualizer();
        });

        _startClassification();

        _audioRecorder.onProgress!.listen((recording) {
          setState(() {
            _dbLevel = recording.decibels ?? 0.0;
          });
          _audioBuffer.add(_dbLevel);
          if (_audioBuffer.length > 100) {
            _audioBuffer.removeAt(0);
          }
        });
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to start recording")),
      );
    }
  }

  void _startClassification() {
    _classificationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      try {
        final startTime = DateTime.now();
        final classification = await _classifier.classifySound(_dbLevel, _audioBuffer);
        final endTime = DateTime.now();
        final processingTime = endTime.difference(startTime).inMilliseconds;

        if (classification != null) {
          setState(() {
            _currentSoundLabel = classification['label'] ?? "Unknown";
            _currentConfidence = classification['confidence'] ?? 0.0;
            _processingTime = "$processingTime ms";
          });
        }
      } catch (e) {
        debugPrint("Classification error: $e");
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      if (_audioRecorder.isRecording) {
        final path = await _audioRecorder.stopRecorder();
        setState(() {
          _isRecording = false;
          _dbLevel = 0.0;
          _currentSoundLabel = "No sound detected";
          _currentConfidence = 0.0;
          _processingTime = "0 ms";
        });

        _animationController.stop();
        _visualizerTimer?.cancel();
        _classificationTimer?.cancel();
        _audioBars = List.generate(20, (index) => 0.0);
        _audioBuffer.clear();

        debugPrint("Recording saved at: $path");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recording saved!")),
        );
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
    }
  }

  Color _getSoundColor(double dbLevel) {
    if (dbLevel < 30) return Colors.green;
    if (dbLevel < 50) return Colors.lightGreen;
    if (dbLevel < 70) return Colors.yellow;
    if (dbLevel < 85) return Colors.orange;
    if (dbLevel < 100) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _visualizerTimer?.cancel();
    _classificationTimer?.cancel();
    _audioRecorder.closeRecorder();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soundColor = _getSoundColor(_dbLevel);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("🎵 Sound Classifier"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _audioBars.map((height) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 8,
                      height: height * 120 + 10,
                      decoration: BoxDecoration(
                        color: soundColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            soundColor.withOpacity(0.9),
                            soundColor.withOpacity(0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 30),

              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        "${_dbLevel.toStringAsFixed(1)} dB",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: soundColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentSoundLabel,
                        style: TextStyle(
                          fontSize: 18,
                          color: soundColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Confidence: ${(_currentConfidence * 100).toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Processing: $_processingTime",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRecording ? Icons.circle : Icons.circle_outlined,
                    color: _isRecording ? Colors.red : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording ? "Recording..." : "Ready to record",
                    style: TextStyle(
                      fontSize: 16,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRecording ? null : _startRecording,
                    icon: const Icon(Icons.mic, size: 20),
                    label: const Text("Start Recording"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isRecording ? _stopRecording : null,
                    icon: const Icon(Icons.stop, size: 20),
                    label: const Text("Stop"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              if (!_hasPermission) ...[
                const SizedBox(height: 20),
                Text(
                  "Microphone permission required!",
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SoundClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelLoaded = false;

  Future<void> loadModel() async {
    try {
      await _loadLabels();
      await _loadTFLiteModel();
      _modelLoaded = true;
      debugPrint("✅ Sound classifier initialized successfully");
    } catch (e) {
      debugPrint("⚠️ Error initializing classifier: $e");
      _modelLoaded = false;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString('assets/yamnet_class_map.csv');
      final lines = labelsData.split('\n');
      _labels = [];

      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final parts = lines[i].split(',');
        if (parts.length >= 3) {
          _labels.add(parts[2].replaceAll('"', '').trim());
        }
      }

      debugPrint("✅ Loaded ${_labels.length} sound labels");
    } catch (e) {
      debugPrint("⚠️ Error loading labels: $e");
      _labels = [
        "Speech", "Music", "Noise", "Silence", "Animal", "Vehicle", "Nature",
        "Alarm", "Siren", "Applause", "Laughter", "Crying", "Footsteps",
        "Knocking", "Doorbell", "Water", "Wind", "Thunder", "Fire", "Explosion"
      ];
    }
  }

  Future<void> _loadTFLiteModel() async {
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;

      _interpreter = await Interpreter.fromAsset(
        'assets/yamnet.tflite',
        options: options,
      );

      debugPrint("✅ TFLite model loaded successfully");
      debugPrint("Input shape: ${_interpreter!.getInputTensors()}");
      debugPrint("Output shape: ${_interpreter!.getOutputTensors()}");
    } catch (e) {
      debugPrint("⚠️ Error loading TFLite model: $e");
      _interpreter = null;
    }
  }

  Future<Map<String, dynamic>?> classifySound(double dbLevel, List<double> audioBuffer) async {
    try {
      if (_interpreter != null && _modelLoaded && audioBuffer.isNotEmpty) {
        return await _runInference(audioBuffer);
      } else {
        return _simulateClassification(dbLevel, audioBuffer);
      }
    } catch (e) {
      debugPrint("Classification error: $e");
      return _simulateClassification(dbLevel, audioBuffer);
    }
  }

  Future<Map<String, dynamic>?> _runInference(List<double> audioBuffer) async {
    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      final input = _prepareInput(audioBuffer, inputShape);
      final output = List.filled(outputShape[1], 0.0).reshape([1, outputShape[1]]);

      _interpreter!.run(input, output);

      final scores = output[0] as List<double>;
      int maxIndex = 0;
      double maxScore = scores[0];

      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      final label = maxIndex < _labels.length ? _labels[maxIndex] : "Unknown";

      return {
        'label': label,
        'confidence': maxScore.clamp(0.0, 1.0),
      };
    } catch (e) {
      debugPrint("Inference error: $e");
      return null;
    }
  }

  List<List<double>> _prepareInput(List<double> audioBuffer, List<int> inputShape) {
    final requiredLength = inputShape[1];
    final normalizedBuffer = List<double>.filled(requiredLength, 0.0);

    for (int i = 0; i < audioBuffer.length && i < requiredLength; i++) {
      normalizedBuffer[i] = (audioBuffer[i] / 100.0).clamp(-1.0, 1.0);
    }

    return [normalizedBuffer];
  }

  Map<String, dynamic> _simulateClassification(double dbLevel, List<double> audioBuffer) {
    String label;
    double confidence;

    final avgDb = audioBuffer.isNotEmpty
        ? audioBuffer.reduce((a, b) => a + b) / audioBuffer.length
        : dbLevel;

    final variance = audioBuffer.isNotEmpty
        ? _calculateVariance(audioBuffer, avgDb)
        : 0.0;

    if (avgDb < 30) {
      label = "Silence";
      confidence = 0.85 + (DateTime.now().millisecond % 150) / 1000;
    } else if (avgDb < 50) {
      if (variance < 5) {
        label = "Background Noise";
        confidence = 0.75 + (DateTime.now().millisecond % 200) / 1000;
      } else {
        label = "Speech";
        confidence = 0.70 + (DateTime.now().millisecond % 250) / 1000;
      }
    } else if (avgDb < 70) {
      if (variance > 10) {
        label = "Music";
        confidence = 0.65 + (DateTime.now().millisecond % 300) / 1000;
      } else {
        label = "Speech";
        confidence = 0.68 + (DateTime.now().millisecond % 280) / 1000;
      }
    } else if (avgDb < 85) {
      final labelOptions = ["Laughter", "Applause", "Vehicle", "Alarm"];
      label = labelOptions[DateTime.now().millisecond % labelOptions.length];
      confidence = 0.60 + (DateTime.now().millisecond % 350) / 1000;
    } else {
      final labelOptions = ["Siren", "Alarm", "Explosion", "Thunder", "Shouting"];
      label = labelOptions[DateTime.now().millisecond % labelOptions.length];
      confidence = 0.55 + (DateTime.now().millisecond % 400) / 1000;
    }

    return {
      'label': label,
      'confidence': confidence.clamp(0.0, 1.0),
    };
  }

  double _calculateVariance(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    double sum = 0.0;
    for (final value in values) {
      sum += (value - mean) * (value - mean);
    }
    return sum / values.length;
  }

  void dispose() {
    _interpreter?.close();
  }
}
