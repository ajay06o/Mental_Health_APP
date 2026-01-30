import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/predict_service.dart';
import '../widgets/app_logo.dart';

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
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) {
      _language = AppLanguage.telugu;
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      _language = AppLanguage.hindi;
    } else {
      _language = AppLanguage.english;
    }
  }

  // ==============================
  // LOAD HISTORY
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
    } catch (_) {
      _showError("Failed to load history");
    }
  }

  // ==============================
  // ANALYZE
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
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showError("Analysis failed. Please try again.");
      }
    }
  }

  // ==============================
  // HELPERS
  // ==============================
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

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
    final map = {
      AppLanguage.telugu: {
        "happy": "సంతోషం",
        "sad": "విషాదం",
        "anxiety": "ఆందోళన",
        "stress": "ఆందోళన",
        "angry": "కోపం",
        "depression": "డిప్రెషన్",
        "suicidal": "ఆత్మహత్య ఆలోచనలు",
      },
      AppLanguage.hindi: {
        "happy": "खुशी",
        "sad": "उदासी",
        "anxiety": "चिंता",
        "stress": "चिंता",
        "angry": "गुस्सा",
        "depression": "अवसाद",
        "suicidal": "आत्महत्या के विचार",
      },
    };
    return map[_language]?[emotion.toLowerCase()] ?? emotion;
  }

  DateTime _toIST(DateTime utc) =>
      utc.add(const Duration(hours: 5, minutes: 30));

  // ==============================
  // GRAPH (UNCHANGED CORE)
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
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
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
                  return LineTooltipItem(
                    "${_emoji(p.emotion)} ${_localizedEmotion(p.emotion)}\n"
                    "${DateFormat('dd MMM, hh:mm a').format(_toIST(p.time))}",
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ==============================
  // UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MindEase Dashboard"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: AppLogo(size: 32, color: Colors.white),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _language == AppLanguage.telugu
                        ? "మీ భావాలను పంచుకోండి..."
                        : _language == AppLanguage.hindi
                            ? "आप कैसा महसूस कर रहे हैं लिखें..."
                            : "Share how you feel...",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _analyze,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Analyze"),
              ),
            ),

            if (_currentEmotion != null) ...[
              const SizedBox(height: 12),
              Chip(
                avatar: Text(_emoji(_currentEmotion!)),
                label: Text(
                  _localizedEmotion(_currentEmotion!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],

            const SizedBox(height: 12),
            _graph(),
          ],
        ),
      ),
    );
  }
}
