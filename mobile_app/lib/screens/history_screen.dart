import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _filterKey = "history_filter";
  static const _searchKey = "history_search";

  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _semanticResults = [];

  bool _loading = true;
  bool _semanticLoading = false;
  bool _semanticMode = false;

  String _selectedEmotion = "all";
  String _searchText = "";

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===============================
  // STATE
  // ===============================
  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedEmotion = prefs.getString(_filterKey) ?? "all";
      _searchText = prefs.getString(_searchKey) ?? "";
      _searchController.text = _searchText;
    });
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filterKey, _selectedEmotion);
    await prefs.setString(_searchKey, _searchText);
  }

  // ===============================
  // LOAD HISTORY
  // ===============================
  Future<void> _loadHistory() async {
    setState(() => _loading = true);

    try {
      final data = await PredictService.fetchHistory();
      if (!mounted) return;

      setState(() {
        _allHistory = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // ===============================
  // FILTER
  // ===============================
  List<Map<String, dynamic>> get filteredHistory {
    final keywords = _searchText.toLowerCase().split(RegExp(r'\s+'));

    return _allHistory.where((h) {
      final emotion = h["emotion"].toString().toLowerCase();
      final synonyms = emotionSynonyms[emotion]?.join(" ") ?? "";

      final searchable =
          "$emotion $synonyms ${h["severity"]} ${h["confidence"]}".toLowerCase();

      if (_selectedEmotion != "all" && emotion != _selectedEmotion) {
        return false;
      }

      for (final k in keywords) {
        if (k.isNotEmpty && !searchable.contains(k)) return false;
      }

      return true;
    }).toList();
  }

  // ===============================
  // SEMANTIC SEARCH
  // ===============================
  Future<void> _runSemanticSearch() async {
    if (_searchText.trim().isEmpty) return;

    setState(() => _semanticLoading = true);

    try {
      final results = await PredictService.semanticSearch(_searchText);
      if (!mounted) return;

      setState(() {
        _semanticResults = results;
        _semanticLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _semanticResults = [];
        _semanticLoading = false;
      });
    }
  }

  // ===============================
  // EMOTION COLOR
  // ===============================
  Color _emotionColor(String emotion) {
    switch (emotion) {
      case "happy":
        return Colors.green;
      case "sad":
        return Colors.blue;
      case "anxiety":
        return Colors.orange;
      case "angry":
        return Colors.red;
      case "depression":
        return Colors.deepPurple;
      case "suicidal":
        return Colors.black87;
      default:
        return Colors.grey;
    }
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final history = _semanticMode ? _semanticResults : filteredHistory;

    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: Column(
          children: [
            _buildSearchSection(),
            _buildEmotionChips(),
            Expanded(
              child: (_loading || _semanticLoading)
                  ? const Center(child: CircularProgressIndicator())
                  : history.isEmpty
                      ? const Center(child: Text("No records found"))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: history.length,
                          itemBuilder: (_, i) {
                            final h = history[i];
                            final emotion =
                                h["emotion"].toString().toLowerCase();

                            return Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              margin:
                                  const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.all(16),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _emotionColor(emotion)
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        emotion.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _emotionColor(emotion),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8),
                                  child: Text(
                                    "Confidence: ${(h["confidence"] * 100).toStringAsFixed(1)}%  |  Severity: ${h["severity"]}",
                                  ),
                                ),
                                trailing: _semanticMode
                                    ? const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.deepPurple,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search emotion or meaning...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onChanged: (v) {
          setState(() => _searchText = v);
          _persistState();
        },
        onSubmitted: (_) {
          if (_semanticMode) _runSemanticSearch();
        },
      ),
    );
  }

  Widget _buildEmotionChips() {
    final emotions = ["all", ...emotionSynonyms.keys];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: emotions.length,
        itemBuilder: (_, i) {
          final e = emotions[i];
          final selected = _selectedEmotion == e;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ChoiceChip(
              label: Text(e.toUpperCase()),
              selected: selected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedEmotion = e);
                _persistState();
              },
            ),
          );
        },
      ),
    );
  }
}
