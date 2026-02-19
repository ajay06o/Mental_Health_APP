import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/predict_service.dart';
import '../widgets/app_logo.dart';

enum AppLanguage { english, telugu, hindi }

class TrendPoint {
  final String emotion;
  final DateTime time;

  TrendPoint(this.emotion, this.time);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller =
      TextEditingController();

  final List<TrendPoint> _points = [];

  bool _loading = false;
  String? _currentEmotion;
  AppLanguage _language =
      AppLanguage.english;

  // ==============================
  // INIT
  // ==============================
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
    if (RegExp(r'[\u0C00-\u0C7F]')
        .hasMatch(text)) {
      _language = AppLanguage.telugu;
    } else if (RegExp(r'[\u0900-\u097F]')
        .hasMatch(text)) {
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
      final data =
          await PredictService.fetchHistory();

      _points
        ..clear()
        ..addAll(data.map(
          (e) => TrendPoint(
            e["emotion"] ?? "unknown",
            DateTime.tryParse(
                        e["timestamp"] ?? "")
                    ?.toUtc() ??
                DateTime.now().toUtc(),
          ),
        ));

      _points.sort(
          (a, b) => a.time.compareTo(b.time));

      if (mounted) setState(() {});
    } catch (_) {
      _showError(
          "Failed to load history");
    }
  }

  // ==============================
  // ANALYZE
  // ==============================
  Future<void> _analyze() async {
    final text =
        _controller.text.trim();
    if (text.isEmpty ||
        _loading) return;

    _autoDetectLanguage(text);
    setState(() => _loading = true);

    try {
      final result =
          await PredictService
              .predictEmotion(text);

      final emotion =
          result["emotion"] ??
              "unknown";

      _points.add(
        TrendPoint(
          emotion,
          DateTime.tryParse(
                      result["timestamp"] ??
                          "")
                  ?.toUtc() ??
              DateTime.now()
                  .toUtc(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentEmotion = emotion;
        _controller.clear();
        _loading = false;
      });

      _checkCrisis(emotion);
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(
            "Analysis failed. Please try again.");
      }
    }
  }

  // ==============================
  // CRISIS ALERT
  // ==============================
  void _checkCrisis(String emotion) {
    if (emotion.toLowerCase() ==
        "suicidal") {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(
              "🚨 Immediate Support"),
          content: const Text(
              "If you are feeling unsafe, please contact a trusted person or emergency service."),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
                  const Text("Close"),
            ),
          ],
        ),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  double _severity(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":
        return 1;
      case "sad":
        return 2;
      case "anxiety":
      case "stress":
        return 3;
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
        return "😰";
      case "depression":
        return "💔";
      case "suicidal":
        return "🚨";
      default:
        return "😐";
    }
  }

  // ==============================
  // GRAPH
  // ==============================
  Widget _graph() {
    if (_points.length < 2) {
      return const Expanded(
        child: Center(
          child: Text(
            "No trend data yet",
            style:
                TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final spots = List.generate(
      _points.length,
      (i) => FlSpot(
        i.toDouble(),
        _severity(
            _points[i].emotion),
      ),
    );

    return Expanded(
      child: LineChart(
        LineChartData(
          minY: 0.8,
          maxY: 5.2,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 4,
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF6366F1),
                ],
              ),
            ),
          ],
        ),
        duration:
            const Duration(milliseconds: 700),
      ),
    );
  }

  // ==============================
  // UI
  // ==============================
  @override
  Widget build(
      BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text("AI Dashboard"),
        actions: const [
          Padding(
            padding:
                EdgeInsets.only(right: 12),
            child:
                AppLogo(size: 28),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              children: [
                _inputCard(),
                const SizedBox(height: 12),
                _analyzeButton(),
                const SizedBox(height: 16),
                if (_currentEmotion !=
                    null)
                  _emotionCard(),
                const SizedBox(height: 16),
                _graph(),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black
                  .withOpacity(0.3),
              child:
                  const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return Card(
      elevation: 6,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: TextField(
          controller: _controller,
          maxLines: 3,
          decoration:
              const InputDecoration(
            hintText:
                "Share how you feel...",
            border:
                InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _analyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            _loading ? null : _analyze,
        child: const Text("Analyze"),
      ),
    );
  }

  Widget _emotionCard() {
    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 400),
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple
            .withOpacity(0.1),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            _emoji(_currentEmotion!),
            style:
                const TextStyle(
              fontSize: 28,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _currentEmotion!,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
