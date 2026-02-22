import 'dart:ui';
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

  @override
  void initState() {
    super.initState();
    _historyFuture = PredictService.fetchHistory();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A5AE0), Color(0xFF836FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "Failed to load insights",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return const Center(
                    child: Text(
                      "No insights yet.\nStart analyzing emotions.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                _controller.forward();

                final avgSeverity =
                    _calculateAverageSeverity(data);
                final avgConfidence =
                    _calculateAverageConfidence(data);

                return FadeTransition(
                  opacity: _fade,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    children: [
                      _sectionTitle("Overview"),
                      const SizedBox(height: 16),
                      _premiumScoreCard(avgSeverity),
                      const SizedBox(height: 24),
                      _premiumConfidenceCard(avgConfidence),
                      const SizedBox(height: 32),
                      _sectionTitle("Analytics"),
                      const SizedBox(height: 16),
                      _emotionDistributionChart(data),
                      const SizedBox(height: 32),
                      _sectionTitle("AI Insights"),
                      const SizedBox(height: 16),
                      _aiMoodSummary(data),
                      const SizedBox(height: 32),
                      _sectionTitle("Recent Activity"),
                      const SizedBox(height: 14),
                      ...data.take(8).map(_premiumTile),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // SECTION TITLE
  // =========================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // =========================
  // SCORE CARD
  // =========================

  Widget _premiumScoreCard(double avg) {
    return _glassCard(
      child: Column(
        children: [
          const Text(
            "Overall Mental Health Score",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: avg),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // CONFIDENCE CARD
  // =========================

  Widget _premiumConfidenceCard(double confidence) {
    return _glassCard(
      child: Column(
        children: [
          const Text(
            "AI Confidence",
            style:
                TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: confidence),
            duration: const Duration(milliseconds: 900),
            builder: (context, value, child) {
              return SizedBox(
                height: 170,
                width: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 16,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                          Colors.white.withOpacity(0.15)),
                    ),
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 16,
                      backgroundColor: Colors.transparent,
                      valueColor:
                          const AlwaysStoppedAnimation(
                              Colors.white),
                    ),
                    Container(
                      height: 110,
                      width: 110,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF6A5AE0),
                      ),
                    ),
                    Text(
                      "${(value * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // EMOTION DISTRIBUTION
  // =========================

  Widget _emotionDistributionChart(
      List<Map<String, dynamic>> data) {
    final Map<String, int> counts = {};

    for (var entry in data) {
      final emotion = (entry["emotion"] ?? "unknown")
          .toString()
          .trim()
          .toLowerCase();

      counts[emotion] = (counts[emotion] ?? 0) + 1;
    }

    final total = data.length;

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sorted.map((entry) {
          final percent = entry.value / total;

          final name =
              entry.key[0].toUpperCase() +
                  entry.key.substring(1);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white70),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor:
                      Colors.white.withOpacity(0.15),
                  valueColor:
                      const AlwaysStoppedAnimation(
                          Colors.white),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================
  // AI MOOD SUMMARY
  // =========================

  Widget _aiMoodSummary(List<Map<String, dynamic>> data) {
    final Map<String, int> counts = {};

    for (var entry in data) {
      final emotion = (entry["emotion"] ?? "unknown")
          .toString()
          .trim()
          .toLowerCase();

      counts[emotion] = (counts[emotion] ?? 0) + 1;
    }

    final total = data.length;
    final negative =
        (counts["sad"] ?? 0) +
            (counts["anxiety"] ?? 0) +
            (counts["depression"] ?? 0);

    String summary;

    if ((counts["suicidal"] ?? 0) > 0) {
      summary =
          "⚠️ Critical emotional signals detected. Please consider reaching out for support.";
    } else if (negative / total > 0.6) {
      summary =
          "Recent patterns suggest emotional strain. Prioritizing rest and support may help.";
    } else if ((counts["happy"] ?? 0) > total * 0.5) {
      summary =
          "You’ve been feeling mostly positive lately. Emotional stability looks strong.";
    } else {
      summary =
          "Your emotional activity shows mixed signals. Maintaining balance is important.";
    }

    return _glassCard(
      child: Text(
        summary,
        style: const TextStyle(
            color: Colors.white70, height: 1.5),
      ),
    );
  }

  // =========================
  // RECENT TILE
  // =========================

  Widget _premiumTile(Map<String, dynamic> entry) {
    final emotion = entry["emotion"] ?? "unknown";
    final confidence =
        (entry["confidence"] ?? 0).toDouble();
    final timestamp = entry["timestamp"] ?? "";

    final formattedTime = timestamp.isNotEmpty
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(timestamp))
        : "";

    return _glassCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading:
            const Icon(Icons.psychology, color: Colors.white),
        title: Text(
          emotion.toString().toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${(confidence * 100).toStringAsFixed(0)}% confidence\n$formattedTime",
          style:
              const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  // =========================
  // GLASS CARD
  // =========================

  Widget _glassCard(
      {required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
  }

  // =========================
  // CALCULATIONS
  // =========================

  double _calculateAverageSeverity(
      List<Map<String, dynamic>> data) {
    double total = 0;
    for (var entry in data) {
      total +=
          (entry["severity"] ?? 1).toDouble();
    }
    return total / data.length;
  }

  double _calculateAverageConfidence(
      List<Map<String, dynamic>> data) {
    double total = 0;
    for (var entry in data) {
      total +=
          (entry["confidence"] ?? 0).toDouble();
    }
    return total / data.length;
  }
}