import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/predict_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _historyFuture = PredictService.fetchHistory();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _historyFuture = PredictService.fetchHistory();
    });
  }

  // =============================
  // SEVERITY COLOR
  // =============================
  Color _severityColor(int severity) {
    switch (severity) {
      case 5:
        return Colors.red.shade700;
      case 4:
        return Colors.orange.shade700;
      case 3:
        return Colors.amber.shade700;
      case 2:
        return Colors.lightGreen.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  String _severityLabel(int severity) {
    switch (severity) {
      case 5:
        return "Critical";
      case 4:
        return "High";
      case 3:
        return "Moderate";
      case 2:
        return "Mild";
      default:
        return "Stable";
    }
  }

  // =============================
  // BUILD
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Insights")),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Failed to load insights"));
            }

            final data = snapshot.data ?? [];

            if (data.isEmpty) {
              return const Center(
                child: Text(
                  "No insights yet.\nStart analyzing emotions.",
                  textAlign: TextAlign.center,
                ),
              );
            }

            _controller.forward();

            final avgSeverity = _calculateAverageSeverity(data);
            final severityRounded = avgSeverity.round();
            final avgConfidence = _calculateAverageConfidence(data);

            return FadeTransition(
              opacity: _fade,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slide.value),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _summaryCard(avgSeverity, severityRounded),
                        const SizedBox(height: 20),
                        _confidenceCard(avgConfidence),
                        const SizedBox(height: 20),
                        const Text(
                          "Recent Activity",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...data.take(10).map(_historyTile),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // =============================
  // SUMMARY CARD
  // =============================
  Widget _summaryCard(double avg, int severity) {
    final color = _severityColor(severity);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text(
              "Overall Mental Health Score",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              avg.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _severityLabel(severity),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // CONFIDENCE CARD
  // =============================
  Widget _confidenceCard(double confidence) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "AI Confidence",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: confidence,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 8),
            Text("${(confidence * 100).toStringAsFixed(1)}%"),
          ],
        ),
      ),
    );
  }

  // =============================
  // HISTORY TILE
  // =============================
  Widget _historyTile(Map<String, dynamic> entry) {
    final emotion = entry["emotion"] ?? "unknown";
    final confidence = (entry["confidence"] ?? 0).toDouble();
    final severity = entry["severity"] ?? 1;
    final platform = entry["platform"] ?? "manual";
    final timestamp = entry["timestamp"] ?? "";

    final color = _severityColor(severity);

    final formattedTime = timestamp.isNotEmpty
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(timestamp))
        : "";

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.psychology, color: color),
        ),
        title: Text(
          emotion.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Confidence: ${(confidence * 100).toStringAsFixed(0)}%"),
            Text("Platform: $platform"),
            Text(formattedTime),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _severityLabel(severity),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // =============================
  // AVG CALCULATIONS
  // =============================
  double _calculateAverageSeverity(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0;
    double total = 0;
    for (var entry in data) {
      total += (entry["severity"] ?? 1).toDouble();
    }
    return total / data.length;
  }

  double _calculateAverageConfidence(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0;
    double total = 0;
    for (var entry in data) {
      total += (entry["confidence"] ?? 0).toDouble();
    }
    return total / data.length;
  }
}
