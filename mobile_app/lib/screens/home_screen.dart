import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/predict_service.dart';
import '../widgets/app_logo.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<TrendPoint> _points = [];
  List<FlSpot> _spots = [];

  bool _loading = false;
  bool _historyLoading = true;
  String? _currentEmotion;

  // 🆕 AI INSIGHT VARIABLES
  String? _trend;
  Map<String, dynamic>? _futurePrediction;
  Map<String, dynamic>? _adaptiveAnalysis;
  int? _mentalHealthIndex;

  late AnimationController _bgController;
  late AnimationController _emojiController;
  late Animation<double> _emojiAnimation;
  late AnimationController _graphController;
  late Animation<double> _graphFade;
  late Animation<Offset> _graphSlide;

  @override
  void initState() {
    super.initState();

    _loadHistory();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

    _emojiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _emojiAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _emojiController,
        curve: Curves.elasticOut,
      ),
    );

    

    _graphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _graphFade = CurvedAnimation(
      parent: _graphController,
      curve: Curves.easeOut,
    );

    _graphSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _graphController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgController.dispose();
    _graphController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  DateTime? _parseTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final parsed = DateTime.parse(raw);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      try {
        final parsed =
            DateFormat("yyyy-MM-dd HH:mm:ss").parseUtc(raw);
        return parsed.toLocal();
      } catch (_) {
        debugPrint("Invalid timestamp: $raw");
        return null;
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await PredictService.fetchHistory();

      final loadedPoints = <TrendPoint>[];

      for (final e in data) {
        final raw = e["created_at"];
        if (raw != null) {
          final parsed = DateTime.parse(raw);
          loadedPoints.add(
            TrendPoint(
              e["emotion"] ?? "unknown",
              parsed.isUtc ? parsed.toLocal() : parsed,
            ),
          );
        }
      }

      loadedPoints.sort((a, b) => a.time.compareTo(b.time));

      if (loadedPoints.length > 30) {
        loadedPoints.removeRange(
          0,
          loadedPoints.length - 30,
        );
      }

      if (!mounted) return;

      setState(() {
        _points
          ..clear()
          ..addAll(loadedPoints);

        _spots = List.generate(
          loadedPoints.length,
          (i) => FlSpot(
            i.toDouble(),
            _severity(loadedPoints[i].emotion),
          ),
        );

        _historyLoading = false;
      });

      _graphController.forward();
    } catch (_) {
      if (mounted) {
        setState(() => _historyLoading = false);
      }
    }
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() => _loading = true);

    try {
      final result =
          await PredictService.predictEmotion(text);

      final emotion = result["emotion"] ?? "unknown";
      final parsedTime =
          _parseTimestamp(result["timestamp"]);

      if (parsedTime != null) {
        _points.add(TrendPoint(emotion, parsedTime));
      }

      if (!mounted) return;

      setState(() {
        _currentEmotion = emotion;
        _controller.clear();
        _loading = false;

        // 🆕 SAVE AI INSIGHTS
        _trend = result["trend"];
        _futurePrediction = result["future_prediction"];
        _adaptiveAnalysis = result["adaptive_analysis"];
        _mentalHealthIndex = result["mental_health_index"];

        _spots = List.generate(
          _points.length,
          (i) => FlSpot(
            i.toDouble(),
            _severity(_points[i].emotion),
          ),
        );
      });
      // 🚨 SHOW HELPLINE IF SUICIDAL
if (emotion.toLowerCase() == "suicidal") {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showHelplinePopup();
  });
}

      _emojiController.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
      case "angry":
        return 4;
      case "depression":
        return 5;
      case "suicidal":
        return 6;
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

  void _showHelplinePopup() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text("You are not alone ❤️"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [

            Text(
              "If you're feeling overwhelmed, please reach out for help.",
            ),

            SizedBox(height: 15),

            ListTile(
              leading: Icon(Icons.phone),
              title: Text("Suicide Helpline India"),
              subtitle: Text("9152987821"),
            ),

            ListTile(
              leading: Icon(Icons.phone),
              title: Text("Kiran Mental Health"),
              subtitle: Text("1800-599-0019"),
            ),

          ],
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ],
      );
    },
  );
}


  Widget _emotionCard() {
  if (_currentEmotion == null) return const SizedBox();

  final emotion = _currentEmotion!.toLowerCase();

  Color accent;
  switch (emotion) {
    case "happy":
      accent = Colors.green;
      break;
    case "sad":
      accent = Colors.blue;
      break;
    case "anxiety":
      accent = Colors.orange;
      break;
    case "angry":
      accent = Colors.red;
      break;
    case "depression":
      accent = Colors.purple;
      break;
    case "suicidal":
      accent = Colors.red.shade900;
      break;
    default:
      accent = Colors.grey;
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 20,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: accent.withOpacity(0.25),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            _emoji(_currentEmotion!),
            style: const TextStyle(fontSize: 30),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentEmotion!.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Your current emotional state",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7A6FF0),
                  Color(0xFF5C9EFF),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Dashboard 🌿",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        AppLogo(size: 32),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _glassInput(),
                    const SizedBox(height: 14),
                    _analyzeButton(),
                    const SizedBox(height: 20),

                    if (_currentEmotion != null)
                      _emotionCard(),

                    const SizedBox(height: 20),

                    Expanded(child: _graph()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- existing widgets below unchanged ----------

  Widget _glassInput() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _controller,
          enabled: !_loading,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: "How are you feeling today?",
            hintStyle: TextStyle(
              color: Colors.grey.shade600,
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    ),
  );
}
  Widget _analyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF6D5DF6),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
        ),
        onPressed:
            _loading ? null : _analyze,
        child: const Text(
          "Analyze",
          style: TextStyle(
              fontWeight:
                  FontWeight.w600),
        ),
      ),
    );
  }

Widget _graph() {
  if (_historyLoading) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  if (_spots.length < 2) {
    return const Center(
      child: Text(
        "No trend data yet",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  final lastIndex = _spots.length - 1;
  final interval = (_spots.length / 4).ceilToDouble();
return FadeTransition(
  opacity: _graphFade,
  child: SlideTransition(
    position: _graphSlide,
    child: RepaintBoundary(   // ✅ colon added
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white,
        ),
        child: LineChart(
          LineChartData(
            minY: 0.8,
            maxY: 6.2,
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),

            titlesData: FlTitlesData(
              topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
       leftTitles: AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    interval: 1,
    reservedSize: 40,
    getTitlesWidget: (value, meta) {
      const style = TextStyle(
        fontSize: 22,
        color: Colors.black,
      );

      switch (value.toInt()) {
        case 1:
          return const Text("😊", style: style);
        case 2:
          return const Text("😔", style: style);
        case 3:
          return const Text("😰", style: style);
        case 4:
          return const Text("😡", style: style);
        case 5:
          return const Text("💔", style: style);
        case 6:
          return const Text("🚨", style: style);
        default:
          return const SizedBox();
      }
    },
  ),
),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (_points.length / 5).ceilToDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= _points.length) {
                      return const SizedBox();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat("MMM d")
                            .format(_points[index].time),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xFF2F3E46),
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.all(12),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final point = _points[index];

                    final emoji = _emoji(point.emotion);
                    final date = DateFormat("MMM d, yyyy")
                        .format(point.time);
                    final time =
                        DateFormat("HH:mm").format(point.time);

                    return LineTooltipItem(
                      "$emoji  ${point.emotion.toUpperCase()}\n$date\n$time",
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    );
                  }).toList();
                },
              ),
            ),

            lineBarsData: [
              LineChartBarData(
                spots: _spots,
                isCurved: true,
                barWidth: 4,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF7A6FF0),
                    Color(0xFF5C9EFF),
                  ],
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter:
                      (spot, percent, bar, index) {
                    if (index == lastIndex) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: const Color(0xFF7A6FF0),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    }
                    return FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFF5C9EFF),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
    }