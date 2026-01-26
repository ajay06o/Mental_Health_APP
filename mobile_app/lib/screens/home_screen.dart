import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/predict_service.dart';
import 'package:intl/intl.dart';

/// ==============================
/// LANGUAGE ENUM
/// ==============================
enum AppLanguage { english, telugu, hindi }

class TrendPoint {
  final String emotion;
  final DateTime time;

  TrendPoint(this.emotion, this.time);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<TrendPoint> _points = [];

  bool _loading = false;
  String? _currentEmotion;
  AppLanguage _language = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==============================
  // AUTO LANGUAGE DETECT
  // ==============================
  void _autoDetectLanguage(String text) {
    final teluguRegex = RegExp(r'[\u0C00-\u0C7F]');
    final hindiRegex = RegExp(r'[\u0900-\u097F]');

    if (teluguRegex.hasMatch(text)) {
      _language = AppLanguage.telugu;
    } else if (hindiRegex.hasMatch(text)) {
      _language = AppLanguage.hindi;
    } else {
      _language = AppLanguage.english;
    }
  }

  // ==============================
  // LOAD HISTORY (SAFE)
  // ==============================
  Future<void> _loadHistory() async {
    try {
      final data = await PredictService.fetchHistory();

      _points
        ..clear()
        ..addAll(
          data.map(
            (e) => TrendPoint(
              e["emotion"] ?? "unknown",
              DateTime.tryParse(e["timestamp"] ?? "")?.toUtc() ??
                  DateTime.now().toUtc(),
            ),
          ),
        );

      _points.sort((a, b) => a.time.compareTo(b.time));
      if (mounted) setState(() {});
    } catch (e) {
      _showError("Failed to load history");
    }
  }

  // ==============================
  // ANALYZE (SAFE)
  // ==============================
  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    _autoDetectLanguage(text);

    setState(() => _loading = true);

    try {
      final result = await PredictService.predictEmotion(text);

      _points.add(
        TrendPoint(
          result["emotion"] ?? "unknown",
          DateTime.tryParse(result["timestamp"] ?? "")?.toUtc() ??
              DateTime.now().toUtc(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentEmotion = result["emotion"];
        _controller.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError("Analysis failed. Please try again.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ==============================
  // SEVERITY VALUE
  // ==============================
  double _severityFromEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":
        return 1;
      case "sad":
        return 2;
      case "anxiety":
      case "stress":
        return 3;
      case "angry":
        return 3.5;
      case "depression":
        return 4;
      case "suicidal":
        return 5;
      default:
        return 2.5;
    }
  }

  // ==============================
  // SEVERITY LABEL
  // ==============================
  String _severityLabel(double s) {
    switch (_language) {
      case AppLanguage.telugu:
        if (s <= 1.5) return "తక్కువ";
        if (s <= 2.5) return "సాధారణం";
        if (s <= 3.5) return "మధ్యస్థం";
        if (s <= 4.5) return "ఎక్కువ";
        return "తీవ్రమైన";

      case AppLanguage.hindi:
        if (s <= 1.5) return "कम";
        if (s <= 2.5) return "सामान्य";
        if (s <= 3.5) return "मध्यम";
        if (s <= 4.5) return "उच्च";
        return "गंभीर";

      case AppLanguage.english:
      default:
        if (s <= 1.5) return "Low";
        if (s <= 2.5) return "Mild";
        if (s <= 3.5) return "Moderate";
        if (s <= 4.5) return "High";
        return "Critical";
    }
  }

  // ==============================
  // EMOJI
  // ==============================
  String _emoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":
        return "😊";
      case "sad":
        return "😔";
      case "anxiety":
      case "stress":
        return "😰";
      case "angry":
        return "😡";
      case "depression":
        return "💔";
      case "suicidal":
        return "🚨";
      default:
        return "😐";
    }
  }

  String _localizedEmotion(String emotion) {
    switch (_language) {
      case AppLanguage.telugu:
        return {
              "happy": "సంతోషం",
              "sad": "విషాదం",
              "anxiety": "ఆందోళన",
              "stress": "ఆందోళన",
              "angry": "కోపం",
              "depression": "డిప్రెషన్",
              "suicidal": "ఆత్మహత్య ఆలోచనలు",
            }[emotion.toLowerCase()] ??
            "సాధారణం";

      case AppLanguage.hindi:
        return {
              "happy": "खुशी",
              "sad": "उदासी",
              "anxiety": "चिंता",
              "stress": "चिंता",
              "angry": "गुस्सा",
              "depression": "अवसाद",
              "suicidal": "आत्महत्या के विचार",
            }[emotion.toLowerCase()] ??
            "सामान्य";

      case AppLanguage.english:
      default:
        return emotion;
    }
  }

  DateTime _toIST(DateTime utc) =>
      utc.add(const Duration(hours: 5, minutes: 30));

  // ==============================
  // GRAPH (UNCHANGED LOGIC)
  // ==============================
  Widget _graph() {
    if (_points.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Not enough data to show trend"),
      );
    }

    final spots = List.generate(
      _points.length,
      (i) => FlSpot(
        i.toDouble(),
        _severityFromEmotion(_points[i].emotion),
      ),
    );

    return Expanded(
      child: LineChart(
        LineChartData(
          minY: 0.8,
          maxY: 5.2,
          clipData: FlClipData.all(),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 36,
                getTitlesWidget: (value, _) {
                  return Text(_emoji(
                    ["", "happy", "sad", "anxiety", "depression", "suicidal"]
                        .elementAt(value.round().clamp(0, 5)),
                  ));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= _points.length) {
                    return const SizedBox.shrink();
                  }
                  return Text("E${i + 1}");
                },
              ),
            ),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: 4,
              color: Colors.deepPurple,
              dotData: FlDotData(show: true),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black87,
              getTooltipItems: (touched) {
                return touched.map((spot) {
                  final p = _points[spot.spotIndex];
                  final sev = _severityFromEmotion(p.emotion);
                  return LineTooltipItem(
                    "${_emoji(p.emotion)} ${_localizedEmotion(p.emotion)}\n"
                    "Severity: ${_severityLabel(sev)} (${sev.toStringAsFixed(1)})\n"
                    "Time: ${DateFormat('dd MMM, hh:mm a').format(_toIST(p.time))}",
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // ==============================
  // UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mental Health Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _language == AppLanguage.telugu
                    ? "మీ భావాలను పంచుకోండి..."
                    : _language == AppLanguage.hindi
                        ? "आप कैसा महसूस कर रहे हैं लिखें..."
                        : "Share how you feel...",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _analyze,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Analyze"),
            ),
            const SizedBox(height: 16),
            if (_currentEmotion != null)
              Chip(
                label: Text(
                  "${_emoji(_currentEmotion!)} ${_localizedEmotion(_currentEmotion!)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),
            _graph(),
          ],
        ),
      ),
    );
  }
}
