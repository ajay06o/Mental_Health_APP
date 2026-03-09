import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/predict_service.dart';

const Map<String, List<String>> emotionSynonyms = {
  "happy": ["happy", "joy", "joyful", "సంతోషం", "खुशी"],
  "sad": ["sad", "unhappy", "విషాదం", "दुख"],
  "anxiety": ["anxiety", "stress", "ఆందోళన", "चिंता"],
  "angry": ["angry", "anger", "కోపం", "गुस्सा"],
  "depression": ["depression", "depressed", "డిప్రెషన్", "अवसाद"],
  "suicidal": ["suicidal", "suicide", "ఆత్మహత్య", "आत्महत्या"],
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _allHistory = [];
  bool _loading = true;

  String _searchText = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final data = await PredictService.fetchHistory();
      if (!mounted) return;
      setState(() {
        _allHistory = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchText = value;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchText = "");
  }

  List<Map<String, dynamic>> get filteredHistory {
    final search = _searchText.trim().toLowerCase();

    if (search.isEmpty) return _allHistory;
    if (search.length < 2) return [];

    return _allHistory.where((item) {
      final emotion = item["emotion"].toString().toLowerCase();
      final synonyms = emotionSynonyms[emotion] ?? [];

      if (emotion.contains(search)) return true;
      if (synonyms.any((e) => e.toLowerCase().contains(search))) return true;

      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final history = filteredHistory;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7A6FF0), Color(0xFF5C9EFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "History 📜",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withOpacity(0.15),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search emotion...",
                          hintStyle:
                              const TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                          suffixIcon: _searchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white),
                      )
                    : history.isEmpty
                        ? const Center(
                            child: Text(
                              "No records found",
                              style:
                                  TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: history.length,
                            itemBuilder: (_, index) {
                              final item = history[index];
                              final emotion =
                                  item["emotion"].toString().toLowerCase();
                              final recordId = item["id"];

                              return Dismissible(
                                key: ValueKey(recordId),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  alignment: Alignment.centerRight,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius:
                                        BorderRadius.circular(22),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                onDismissed: (_) async {
                                  final removedItem = item;

                                  setState(() {
                                    _allHistory.removeWhere(
                                        (e) => e["id"] == recordId);
                                  });

                                  try {
                                    await PredictService
                                        .deleteHistory(recordId);
                                  } catch (_) {
                                    setState(() {
                                      _allHistory.insert(
                                          index, removedItem);
                                    });

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("Delete failed"),
                                      ),
                                    );
                                    return;
                                  }

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("History deleted"),
                                    ),
                                  );
                                },
                                child: _HistoryCard(
                                  emotion: emotion,
                                  confidence:
                                      (item["confidence"] as num)
                                          .toDouble(),
                                  severity: item["severity"],
                                  createdAt: item["created_at"]
                                      ?.toString(),

                                  // 🆕 NEW OPTIONAL FIELDS
                                  risk: item["risk"],
                                  mentalHealthIndex:
                                      item["mental_health_index"],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String emotion;
  final double confidence;
  final dynamic severity;
  final String? createdAt;

  // 🆕 NEW FIELDS
  final String? risk;
  final int? mentalHealthIndex;

  const _HistoryCard({
    required this.emotion,
    required this.confidence,
    required this.severity,
    required this.createdAt,
    this.risk,
    this.mentalHealthIndex,
  });

  String _emoji(String emotion) {
    switch (emotion) {
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

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "";

    try {
      final parsed = DateTime.parse(date).toLocal();
      return DateFormat('dd MMM yyyy • hh:mm a')
          .format(parsed);
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDate(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_emoji(emotion),
                  style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emotion.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            "Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
            style: const TextStyle(color: Colors.white70),
          ),

          // 🆕 RISK LEVEL
          if (risk != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Risk: $risk",
                style: const TextStyle(
                    color: Colors.orangeAccent),
              ),
            ),

          // 🆕 MENTAL HEALTH INDEX
          if (mentalHealthIndex != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "MHI: $mentalHealthIndex",
                style: const TextStyle(
                    color: Colors.lightGreenAccent),
              ),
            ),

          if (formattedDate.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              formattedDate,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}