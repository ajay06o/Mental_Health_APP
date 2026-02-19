import 'package:flutter/material.dart';
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
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _historyFuture = PredictService.fetchHistory();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
  // SEVERITY COLOR LOGIC
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Insights"),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text("Failed to load insights"),
              );
            }

            final data = snapshot.data ?? [];

            if (data.isEmpty) {
              return const Center(
                child: Text(
                  "No data available.\nStart analyzing emotions.",
                  textAlign: TextAlign.center,
                ),
              );
            }

            _controller.forward();

            final avgSeverity = _calculateAverageSeverity(data);
            final highRisk = avgSeverity >= 3.5;

            return FadeTransition(
              opacity: _fadeAnimation,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(avgSeverity, highRisk),
                  const SizedBox(height: 20),

                  const Text(
                    "Recent Activity",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  ...data.map((entry) => _historyTile(entry)),
                ],
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
  Widget _summaryCard(double avgSeverity, bool highRisk) {
    final severityRounded = avgSeverity.round();
    final color = _severityColor(severityRounded);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.7),
            color,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Overall Mental Health Trend",
            style: TextStyle(
                color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            avgSeverity.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            _severityLabel(severityRounded),
            style: const TextStyle(
                color: Colors.white, fontSize: 16),
          ),
          if (highRisk) ...[
            const SizedBox(height: 12),
            const Text(
              "⚠ High risk patterns detected",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
    );
  }

  // =============================
  // HISTORY TILE
  // =============================
  Widget _historyTile(Map<String, dynamic> entry) {
    final emotion = entry["emotion"] ?? "unknown";
    final confidence =
        (entry["confidence"] ?? 0).toDouble();
    final severity = entry["severity"] ?? 1;
    final platform = entry["platform"] ?? "manual";
    final timestamp = entry["timestamp"] ?? "";

    final color = _severityColor(severity);

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.insights, color: color),
        ),
        title: Text(
          emotion.toUpperCase(),
          style: const TextStyle(
              fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text("Confidence: ${(confidence * 100).toStringAsFixed(0)}%"),
            Text("Platform: $platform"),
            Text(timestamp),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
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
  // CALCULATE AVERAGE SEVERITY
  // =============================
  double _calculateAverageSeverity(
      List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 0;

    double total = 0;
    for (var entry in data) {
      total += (entry["severity"] ?? 1).toDouble();
    }

    return total / data.length;
  }
}
