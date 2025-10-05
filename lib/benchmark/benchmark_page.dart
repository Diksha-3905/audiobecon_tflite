import 'package:flutter/material.dart';
import 'benchmark_runner.dart';
import 'inference_benchmark.dart';

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  List<BenchmarkResult>? _results;
  bool _isRunning = false;
  String _status = 'Ready to run benchmarks';

  Future<void> _runBenchmarks() async {
    setState(() {
      _isRunning = true;
      _status = 'Running benchmarks...';
      _results = null;
    });

    try {
      final runner = BenchmarkRunner(
        warmupRuns: 5,
        benchmarkRuns: 50,
      );

      final results = await runner.runAll();

      setState(() {
        _results = results;
        _status = 'Benchmarks completed';
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inference Engine Benchmark'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Benchmark Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Audio Length', '16000 samples (1 second @ 16kHz)'),
                    _buildInfoRow('Warmup Runs', '5'),
                    _buildInfoRow('Benchmark Runs', '50'),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _isRunning ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runBenchmarks,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running...' : 'Run Benchmarks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (_results != null) ...[
              const Text(
                'Results',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _results!.length,
                  itemBuilder: (context, index) {
                    final result = _results![index];
                    return _buildResultCard(result, index);
                  },
                ),
              ),
            ] else if (!_isRunning)
              const Expanded(
                child: Center(
                  child: Text(
                    'Run benchmarks to see results',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BenchmarkResult result, int rank) {
    final isWinner = rank == 0;

    return Card(
      elevation: isWinner ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: isWinner ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isWinner)
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 24,
                  ),
                if (isWinner) const SizedBox(width: 8),
                Text(
                  result.engineName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isWinner ? Colors.amber.shade900 : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              'Avg Inference Time',
              '${result.avgInferenceTimeMs.toStringAsFixed(2)} ms',
              Icons.speed,
            ),
            _buildMetricRow(
              'Min / Max',
              '${result.minInferenceTimeMs.toStringAsFixed(2)} / '
                  '${result.maxInferenceTimeMs.toStringAsFixed(2)} ms',
              Icons.trending_flat,
            ),
            _buildMetricRow(
              'Std Deviation',
              '±${result.stdDeviation.toStringAsFixed(2)} ms',
              Icons.show_chart,
            ),
            _buildMetricRow(
              'Model Size',
              '${(result.modelSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB',
              Icons.storage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
