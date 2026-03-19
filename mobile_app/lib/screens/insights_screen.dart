import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/predict_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart'; 

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
  Map<String, dynamic>? socialData;
  bool isLoadingSocial = true;

  bool _crisisDialogShown = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = PredictService.fetchHistory();
    _fetchSocialInsights();

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
    isLoadingSocial = true;
  });

  _fetchSocialInsights(); // important
}
  Future<void> _fetchSocialInsights() async {
  try {
    final data = await PredictService.getSocialInsights();

    setState(() {
      socialData = data;
      isLoadingSocial = false;
    });
  } catch (e) {
    setState(() => isLoadingSocial = false);
  }
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
                /// 🚨 Crisis Detection
/// 🚨 Crisis Detection (show only once)
if (!_crisisDialogShown &&
    data.any((e) =>
        (e["emotion"] ?? "")
            .toString()
            .toLowerCase() == "suicidal")) {

  _crisisDialogShown = true;

  
}

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
                final mentalIndex =
                    _calculateMentalHealthIndex(data);

                return FadeTransition(
                  opacity: _fade,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    children: [
                      // ================= SOCIAL INSIGHTS =================

if (isLoadingSocial)
  const Center(
    child: CircularProgressIndicator(color: Colors.white),
  )
else if (socialData != null) ...[

  _sectionTitle("Social Insights"),
  const SizedBox(height: 16),
  ElevatedButton(
  onPressed: _connectTwitter,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(vertical: 12),
  ),
  child: const Text("Connect Twitter"),
),
const SizedBox(height: 16),

  _glassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Score + Risk
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Score: ${socialData?["mental_health_index"] ?? "--"}",
              style: const TextStyle(color: Colors.white),
            ),

            Text(
  (socialData?["risk_level"] ?? "low").toString().toUpperCase(),
  style: TextStyle(
    fontWeight: FontWeight.bold,
    color: _getRiskColor(
        socialData?["risk_level"] ?? "low"),
  ),
),
          ],
        ),

        const SizedBox(height: 16),

        // Emotion Distribution
        ...((socialData?["emotion_distribution"]
            as Map<String, dynamic>?) ??
        {})
    .entries
    .map((e) {
      final value = (e.value is num) ? e.value.toDouble() : 0.0;

      return Text(
        "${e.key} : ${(value * 100).toInt()}%",
        style: const TextStyle(color: Colors.white70),
      );
    }),
      ],
    ),
  ),

  const SizedBox(height: 30),
],
                      _sectionTitle("Mental Health Index"),
                      const SizedBox(height: 16),
                      _mentalHealthIndexCard(mentalIndex),
                      const SizedBox(height: 32),

                      _sectionTitle("Overview"),
const SizedBox(height: 16),
_overviewDashboardCard(
  avgSeverity,
  avgConfidence,
  mentalIndex,
),
const SizedBox(height: 32),
                      _sectionTitle("Analytics"),
                      const SizedBox(height: 16),
                      _emotionDistributionChart(data),
                      const SizedBox(height: 32),

                      _sectionTitle("AI Insights"),
                      const SizedBox(height: 16),
                      _aiMoodSummary(data),
                      const SizedBox(height: 32),
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

 Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
  );
}

  // ================= MENTAL HEALTH INDEX =================

 Widget _mentalHealthIndexCard(double index) {
  Color progressColor;

  if (index >= 75) {
    progressColor = Colors.greenAccent;
  } else if (index >= 50) {
    progressColor = Colors.orangeAccent;
  } else {
    progressColor = Colors.redAccent;
  }

  final normalizedValue = index / 100;

  return _glassCard(
    child: Column(
      children: [
        const Text(
          "Overall Emotional Stability Score",
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 28),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: normalizedValue),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return SizedBox(
              height: 190,
              width: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // Background circle
                  SizedBox(
                    height: 190,
                    width: 190,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 16,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ),

                  // Animated progress
                  SizedBox(
                    height: 190,
                    width: 190,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 16,
                      backgroundColor: Colors.transparent,
                      valueColor:
                          AlwaysStoppedAnimation(progressColor),
                    ),
                  ),

                  // Center circle (glass effect)
                  Container(
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6A5AE0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ),

                  // Score text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (value * 100).toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        index >= 75
                            ? "Stable"
                            : index >= 50
                                ? "Moderate"
                                : "Risk",
                        style: TextStyle(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        Text(
          index >= 75
              ? "Your emotional patterns show strong stability."
              : index >= 50
                  ? "Your emotional balance is moderate."
                  : "Emotional strain detected. Consider support.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

Widget _overviewDashboardCard(
  double severity,
  double confidence,
  double index,
) {
  Color severityColor;
  String riskLabel;
  Color riskColor;

  // Severity color
  if (severity >= 3) {
    severityColor = Colors.redAccent;
  } else if (severity >= 2) {
    severityColor = Colors.orangeAccent;
  } else {
    severityColor = Colors.greenAccent;
  }

  // Risk status
  if (index >= 75) {
    riskLabel = "Low Risk";
    riskColor = Colors.greenAccent;
  } else if (index >= 50) {
    riskLabel = "Moderate";
    riskColor = Colors.orangeAccent;
  } else {
    riskLabel = "High Risk";
    riskColor = Colors.redAccent;
  }

  return _glassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ================= HEADER =================

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Performance Overview",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            // Risk Chip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: riskColor.withOpacity(0.4)),
              ),
              child: Text(
                riskLabel,
                style: TextStyle(
                  color: riskColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ================= METRICS =================

        Row(
          children: [

            Expanded(
              child: _metricBlock(
                label: "Avg Severity",
                value: severity.toStringAsFixed(1),
                icon: Icons.monitor_heart,
                color: severityColor,
                trendUp: severity < 2.5,
              ),
            ),

            Container(
              height: 70,
              width: 1,
              margin:
                  const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            Expanded(
              child: _metricBlock(
                label: "AI Confidence",
                value:
                    "${(confidence * 100).toStringAsFixed(0)}%",
                icon: Icons.psychology,
                color: Colors.blueAccent,
                trendUp: confidence > 0.7,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ================= INDEX =================

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Mental Health Index",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            Text(
              "${index.toStringAsFixed(0)}/100",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: index / 100),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.12),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: _indexGradient(index),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                _indexGlow(index).withOpacity(0.5),
                            blurRadius: 12,
                          )
                        ],
                      ),
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
Widget _metricBlock({
  required String label,
  required String value,
  required IconData icon,
  required Color color,
  required bool trendUp,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
        vertical: 14, horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withOpacity(0.05),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 20),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (trendUp
                        ? Colors.greenAccent
                        : Colors.redAccent)
                    .withOpacity(0.15),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                trendUp
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: trendUp
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: double.tryParse(
                    value.replaceAll('%', '')) ?? 0,
          ),
          duration:
              const Duration(milliseconds: 800),
          builder: (context, val, child) {
            final display = value.contains('%')
                ? "${val.toStringAsFixed(0)}%"
                : val.toStringAsFixed(1);

            return Text(
              display,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),

        const SizedBox(height: 6),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
  // ================= OVERVIEW CARDS =================

  Widget _premiumScoreCard(double avg) {
    return _glassCard(
      child: Column(
        children: [
          const Text(
            "Overall Mental Health Score",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumConfidenceCard(double confidence) {
    return _glassCard(
      child: Column(
        children: [
          const Text(
            "AI Confidence",
            style:
                TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Text(
            "${(confidence * 100).toStringAsFixed(0)}%",
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ================= ANALYTICS =================

  Widget _emotionDistributionChart(
    List<Map<String, dynamic>> data) {

  final Map<String, int> counts = {};

  for (var entry in data) {
    final emotion =
        (entry["emotion"] ?? "unknown")
            .toString()
            .toLowerCase();

    counts[emotion] = (counts[emotion] ?? 0) + 1;
  }

  final total = data.length;

  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return _glassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Emotion Distribution",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 24),

        ...sorted.map((entry) {
          final percent = entry.value / total;
          final percentageText =
              "${(percent * 100).toStringAsFixed(0)}%";

          final color = _emotionColor(entry.key);

          return Padding(
            padding:
                const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      percentageText,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent),
                  duration:
                      const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(30),
                        color: Colors.white
                            .withOpacity(0.12),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(30),
                            color: color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}

Color _emotionColor(String emotion) {
  switch (emotion) {
    case "happy":
      return Colors.greenAccent;
    case "sad":
      return Colors.blueAccent;
    case "anxiety":
      return Colors.orangeAccent;
    case "depression":
      return Colors.purpleAccent; 
    case "suicidal":
      return Colors.redAccent;
    default:
      return Colors.white;
  }
}

  // ================= AI SUMMARY =================

  Widget _aiMoodSummary(List<Map<String, dynamic>> data) {
  final Map<String, int> counts = {};
  double totalSeverity = 0;
  double totalConfidence = 0;

  for (var entry in data) {
    final emotion =
        (entry["emotion"] ?? "unknown")
            .toString()
            .trim()
            .toLowerCase();

    counts[emotion] = (counts[emotion] ?? 0) + 1;

    totalSeverity += _severityToNumber(entry["severity"]);

    final confidence = entry["confidence"];
    if (confidence is num) {
      totalConfidence += confidence.toDouble();
    }
  }

  final total = data.length;
  final avgSeverity = totalSeverity / total;
  final avgConfidence = totalConfidence / total;
  final mentalIndex = _calculateMentalHealthIndex(data);

  final negative =
      (counts["sad"] ?? 0) +
      (counts["anxiety"] ?? 0) +
      (counts["depression"] ?? 0);

  String summary;

  // 🚨 Highest Priority
  if ((counts["suicidal"] ?? 0) > 0) {
    summary =
        "⚠️ Critical emotional signals detected. Immediate support is strongly recommended.";
  }

  // 🔴 High Risk
  else if (mentalIndex < 40) {
    summary =
        "Your emotional patterns indicate significant distress. High negative trends and elevated severity were observed.";
  }

  // 🟠 Moderate Risk
  else if (mentalIndex < 60) {
    summary =
        "Your recent emotions suggest moderate imbalance. Stress indicators appear more frequently than positive states.";
  }

  // 🟢 Stable
  else if (mentalIndex >= 75) {
    summary =
        "Your emotional state appears stable and balanced. Positive trends dominate recent activity.";
  }

  // ⚖️ Mixed
  else {
    summary =
        "Your emotional signals are mixed. While some strain is present, overall balance remains manageable.";
  }

  // Add intelligent context
  summary +=
      "\n\nAverage Severity: ${avgSeverity.toStringAsFixed(1)}"
      "\nAI Confidence: ${(avgConfidence * 100).toStringAsFixed(0)}%"
      "\nMental Health Index: ${mentalIndex.toStringAsFixed(0)}/100";

  return _glassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI Emotional Analysis",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          summary,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

  // ================= CALCULATIONS =================

  double _calculateMentalHealthIndex(
      List<Map<String, dynamic>> data) {
    int negative = 0;
    double severity = 0;

    for (var entry in data) {
      final emotion =
          (entry["emotion"] ?? "").toString().toLowerCase();

      if (emotion == "sad" ||
          emotion == "anxiety" ||
          emotion == "depression" ||
          emotion == "suicidal") {
        negative++;
      }

      severity += _severityToNumber(entry["severity"]);
    }

    final negativeRatio = negative / data.length;
    final avgSeverity = severity / data.length;
    final normalizedSeverity = avgSeverity / 4;

    final impact =
        (negativeRatio * 0.6) +
        (normalizedSeverity * 0.4);

    return (100 * (1 - impact)).clamp(0, 100);
  }

  double _calculateAverageSeverity(
      List<Map<String, dynamic>> data) {
    double total = 0;
    for (var entry in data) {
      total += _severityToNumber(entry["severity"]);
    }
    return total / data.length;
  }

  double _severityToNumber(dynamic severity) {
    if (severity is num) {
      return severity.toDouble();
    }
    if (severity is String) {
      switch (severity.toLowerCase()) {
        case 'low':
          return 1;
        case 'medium':
          return 2;
        case 'high':
          return 3;
        case 'critical':
          return 4;
      }
    }
    return 1;
  }

  double _calculateAverageConfidence(
      List<Map<String, dynamic>> data) {
    double total = 0;
    for (var entry in data) {
      final value = entry["confidence"];
      if (value is num) {
        total += value.toDouble();
      }
    }
    return total / data.length;
  }

List<Color> _indexGradient(double index) {
  if (index >= 75) {
    return [
      Colors.greenAccent,
      Colors.tealAccent,
    ];
  } else if (index >= 50) {
    return [
      Colors.orangeAccent,
      Colors.deepOrangeAccent,
    ];
  } else {
    return [
      Colors.redAccent,
      Colors.pinkAccent,
    ];
  }
}

Color _indexGlow(double index) {
  if (index >= 75) {
    return Colors.greenAccent;
  } else if (index >= 50) {
    return Colors.orangeAccent;
  } else {
    return Colors.redAccent;
  }
}

  Widget _glassCard({
  required Widget child,
  EdgeInsets? margin,
}) {
  return Container(
    margin: margin,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}
Color _getRiskColor(String risk) {
  switch (risk.toLowerCase()) {
    case "high":
      return Colors.redAccent;
    case "medium":
      return Colors.orangeAccent;
    default:
      return Colors.greenAccent;
  }
}
void _connectTwitter() async {
  try {
    // ✅ Call correct API
    final response = await ApiClient.getPublic("/auth/twitter");

    final authUrl = response["auth_url"];

    if (authUrl == null) {
      print("Auth URL not found");
      return;
    }

    // ✅ Open Twitter login
    await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    print("Twitter error: $e");
  }
}
}
