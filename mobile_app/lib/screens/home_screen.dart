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
  static List<TrendPoint>? _cachedPoints;

  bool _loading = false;
  String? _currentEmotion;

  // 🆕 NEW DYNAMIC FIELDS (DOES NOT AFFECT OLD CODE)
  String? _risk;
  int? _mhi;

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();

    if (_cachedPoints != null) {
      _points.addAll(_cachedPoints!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgController.dispose();
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

      if (!mounted) return;

      setState(() {
        _points
          ..clear()
          ..addAll(loadedPoints);

        _cachedPoints = List.from(loadedPoints);
      });
    } catch (_) {}
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
        _points.add(
          TrendPoint(
            emotion,
            parsedTime,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _currentEmotion = emotion;

        // 🆕 NEW DATA (DOES NOT BREAK OLD LOGIC)
        _risk = result["risk"];
        _mhi = result["mental_health_index"];

        _controller.clear();
        _loading = false;
      });
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

  Widget _mhiCard() {
    if (_mhi == null) return const SizedBox();

    Color color;
    String status;

    if (_mhi! >= 70) {
      color = Colors.green;
      status = "Healthy";
    } else if (_mhi! >= 40) {
      color = Colors.orange;
      status = "Needs Attention";
    } else {
      color = Colors.red;
      status = "Critical";
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.97),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mental Health Index",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$_mhi / 100",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_risk != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          color.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(
                              12),
                    ),
                    child: Text(
                      _risk!.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emotionCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16),
          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(0.97),
            borderRadius:
                BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Text(
                _emoji(_currentEmotion!),
                style:
                    const TextStyle(fontSize: 30),
              ),
              const SizedBox(width: 14),
              Text(
                _currentEmotion!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        Text(
                          "Dashboard 🌿",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Colors.white,
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
                    _mhiCard(),
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

  Widget _glassInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
                  horizontal: 16),
          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(0.9),
            borderRadius:
                BorderRadius.circular(20),
          ),
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
  if (_points.length < 2) {
    return const Center(
      child: Text(
        "No trend data yet",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  final lastIndex = _points.length - 1;
  final interval = (_points.length / 4).ceilToDouble();

  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeOutCubic,
    builder: (context, animationValue, child) {
      final animatedSpots = List.generate(
        _points.length,
        (i) => FlSpot(
          i.toDouble(),
          _severity(_points[i].emotion) * animationValue,
        ),
      );

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF4F6FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LineChart(
          LineChartData(
            minY: 0.8,
            maxY: 6.2,
            borderData: FlBorderData(show: false),
            clipData: FlClipData.all(),

            // 🔥 Soft Grid
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                );
              },
            ),

            // 🔥 Clean Axis
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
        fontSize: 18,
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
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= _points.length) {
                      return const SizedBox();
                    }

                    final date = DateFormat("MMM d")
                        .format(_points[index].time);

                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        date,
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

            // 🔥 Tooltip
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xFF1F1F1F),
                tooltipRoundedRadius: 12,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final emotion =
                        _points[index].emotion.toUpperCase();
                    final time = DateFormat("MMM d, HH:mm")
                        .format(_points[index].time);

                    return LineTooltipItem(
                      "$emotion\n$time",
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),

            // 🔥 Premium Gradient Line
            lineBarsData: [
              LineChartBarData(
                spots: animatedSpots,
                isCurved: true,
                curveSmoothness: 0.4,
                barWidth: 5,
                isStrokeCapRound: true,
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
                        radius: 7,
                        color: const Color(0xFF7A6FF0),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    }
                    return FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFF5C9EFF),
                    );
                  },
                ),

                // 🔥 Soft Glow Area
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF7A6FF0)
                          .withOpacity(0.25),
                      const Color(0xFF5C9EFF)
                          .withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
}