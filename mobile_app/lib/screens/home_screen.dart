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

  bool _loading = false;
  String? _currentEmotion;

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _loadHistory();

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

  // =============================
  // LOAD HISTORY
  // =============================
  Future<void> _loadHistory() async {
    try {
      final data = await PredictService.fetchHistory();

      _points
        ..clear()
        ..addAll(data.map(
          (e) => TrendPoint(
            e["emotion"] ?? "unknown",
            DateTime.tryParse(e["timestamp"] ?? "") ??
                DateTime.now(),
          ),
        ));

      _points.sort((a, b) => a.time.compareTo(b.time));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // =============================
  // ANALYZE
  // =============================
  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() => _loading = true);

    try {
      final result =
          await PredictService.predictEmotion(text);

      final emotion = result["emotion"] ?? "unknown";

      _points.add(
        TrendPoint(
          emotion,
          DateTime.tryParse(result["timestamp"] ?? "") ??
              DateTime.now(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentEmotion = emotion;
        _controller.clear();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =============================
  // SEVERITY
  // =============================
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

  // =============================
  // TREND DIRECTION
  // =============================
  String _trendDirection() {
    if (_points.length < 2) return "stable";

    final last = _severity(_points.last.emotion);
    final prev = _severity(_points[_points.length - 2].emotion);

    if (last > prev) return "worsening";
    if (last < prev) return "improving";
    return "stable";
  }

  Widget _trendIndicator() {
    if (_points.length < 2) return const SizedBox();

    final trend = _trendDirection();

    IconData icon;
    Color color;
    String text;

    switch (trend) {
      case "improving":
        icon = Icons.trending_up;
        color = Colors.green;
        text = "Improving";
        break;
      case "worsening":
        icon = Icons.trending_down;
        color = Colors.red;
        text = "Worsening";
        break;
      default:
        icon = Icons.trending_flat;
        color = Colors.orange;
        text = "Stable";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(
                  -1 + _bgController.value * 2,
                  -1,
                ),
                end: Alignment(
                  1,
                  1 - _bgController.value * 2,
                ),
                colors: const [
                  Color(0xFF7A6FF0),
                  Color(0xFF5C9EFF),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "AI Dashboard 🌿",
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
                  if (_loading)
                    Container(
                      color:
                          Colors.black.withOpacity(0.3),
                      child: const Center(
                        child:
                            CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =============================
  // GLASS INPUT
  // =============================
  Widget _glassInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(0.9),
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _controller,
            style:
                const TextStyle(color: Colors.black),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Share how you feel...",
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
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
        ),
        onPressed: _loading ? null : _analyze,
        child: const Text(
          "Analyze",
          style:
              TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _emotionCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
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
                _currentEmotion!
                    .toUpperCase(),
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

  // =============================
  // GRAPH (FINAL)
  // =============================
  Widget _graph() {
    if (_points.length < 2) {
      return const Center(
        child: Text(
          "No trend data yet",
          style:
              TextStyle(color: Colors.white70),
        ),
      );
    }

    final spots = List.generate(
      _points.length,
      (i) => FlSpot(
        i.toDouble(),
        _severity(_points[i].emotion),
      ),
    );

    final lastIndex =
        _points.length - 1;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _trendIndicator(),

        Expanded(
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 15,
                  sigmaY: 15),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(
                        32, 28, 20, 28),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.98),
                  borderRadius:
                      BorderRadius.circular(
                          20),
                ),
                child: LineChart(
                  LineChartData(
                    minY: 0.8,
                    maxY: 5.3,

                    titlesData:
                        FlTitlesData(
                      leftTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles:
                              true,
                          reservedSize:
                              44,
                          interval: 1,
                          getTitlesWidget:
                              (value,
                                  meta) {
                            const style =
                                TextStyle(
                              fontSize:
                                  18,
                              color:
                                  Colors
                                      .black87,
                            );

                            switch (value
                                .toInt()) {
                              case 1:
                                return const Text(
                                    "😊",
                                    style:
                                        style);
                              case 2:
                                return const Text(
                                    "😔",
                                    style:
                                        style);
                              case 3:
                                return const Text(
                                    "😰",
                                    style:
                                        style);
                              case 4:
                                return const Text(
                                    "💔",
                                    style:
                                        style);
                              case 5:
                                return const Text(
                                    "🚨",
                                    style:
                                        style);
                              default:
                                return const SizedBox();
                            }
                          },
                        ),
                      ),
                      topTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                                showTitles:
                                    false),
                      ),
                      rightTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                                showTitles:
                                    false),
                      ),
                      bottomTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                                showTitles:
                                    false),
                      ),
                    ),

                    gridData:
                        FlGridData(
                      show: true,
                      drawVerticalLine:
                          false,
                      horizontalInterval:
                          1,
                      getDrawingHorizontalLine:
                          (value) {
                        return FlLine(
                          color: Colors.grey
                              .withOpacity(
                                  0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),

                    borderData:
                        FlBorderData(
                            show: false),

                    lineTouchData:
                        LineTouchData(
                      touchTooltipData:
                          LineTouchTooltipData(
                        tooltipBgColor:
                            Colors.black87,
                        getTooltipItems:
                            (touchedSpots) {
                          return touchedSpots
                              .map((spot) {
                            final index =
                                spot.x
                                    .toInt();
                            final emotion =
                                _points[
                                        index]
                                    .emotion
                                    .toUpperCase();
                            final time =
                                DateFormat(
                                        "MMM d, HH:mm")
                                    .format(
                                        _points[
                                                index]
                                            .time);

                            return LineTooltipItem(
                              "$emotion\n$time",
                              const TextStyle(
                                color: Colors
                                    .white,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),

                  lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 3,
                        color: const Color(
                            0xFF6D5DF6),

                        dotData:
                            FlDotData(
                          show: true,
                          getDotPainter:
                              (spot,
                                  percent,
                                  bar,
                                  index) {
                            if (index ==
                                lastIndex) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: const Color(
                                    0xFF6D5DF6),
                                strokeWidth:
                                    4,
                                strokeColor:
                                    Colors
                                        .white,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 3,
                              color: const Color(
                                  0xFF6D5DF6),
                            );
                          },
                        ),

                        belowBarData:
                            BarAreaData(
                          show: true,
                          gradient:
                              LinearGradient(
                            colors: [
                              const Color(
                                      0xFF6D5DF6)
                                  .withOpacity(
                                      0.15),
                              Colors
                                  .transparent,
                            ],
                            begin:
                                Alignment
                                    .topCenter,
                            end: Alignment
                                .bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
