import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/predict_service.dart';

/// ===============================
/// EMOTION SYNONYMS (EN / TE / HI)
/// ===============================
const Map<String, List<String>> emotionSynonyms = {
  "happy": ["happy", "joy", "joyful", "glad", "pleased", "సంతోషం", "ఆనందం", "खुशी", "आनंद"],
  "sad": ["sad", "unhappy", "down", "విషాదం", "దుఃఖం", "उदासी", "दुख"],
  "anxiety": ["anxiety", "stress", "tense", "worried", "ఆందోళన", "టెన్షన్", "चिंता", "तनाव"],
  "angry": ["angry", "anger", "mad", "కోపం", "गुस्सा"],
  "depression": ["depression", "depressed", "hopeless", "empty", "numb", "డిప్రెషన్", "अवसాద"],
  "suicidal": ["suicide", "suicidal", "die", "end", "kill", "ఆత్మహత్య", "आत్మहत्या"],
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

  // ===============================
  // STATE RESTORE
  // ===============================
  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedEmotion = prefs.getString(_filterKey) ?? "all";
    _searchText = prefs.getString(_searchKey) ?? "";
    _searchController.text = _searchText;
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
    final data = await PredictService.fetchHistory();
    if (!mounted) return;
    setState(() {
      _allHistory = data;
      _loading = false;
    });
  }

  // ===============================
  // KEYWORD SEARCH
  // ===============================
  List<Map<String, dynamic>> get filteredHistory {
    final keywords = _searchText.toLowerCase().split(RegExp(r'\s+'));

    return _allHistory.where((h) {
      final emotion = h["emotion"].toString().toLowerCase();
      final synonyms = emotionSynonyms[emotion]?.join(" ") ?? emotion;

      final searchable =
          "${h["text"]} $emotion $synonyms ${h["severity"]}".toLowerCase();

      if (_selectedEmotion != "all" && emotion != _selectedEmotion) return false;

      for (final k in keywords) {
        if (k.isNotEmpty && !searchable.contains(k)) return false;
      }
      return true;
    }).toList();
  }

  // ===============================
  // 🧠 AI SEMANTIC SEARCH (FINAL FIX)
  // ===============================
  Future<void> _runSemanticSearch() async {
    if (_searchText.trim().isEmpty) return;

    setState(() => _semanticLoading = true);

    final results = await PredictService.semanticSearch(_searchText);

    if (!mounted) return;
    setState(() {
      _semanticResults = results;
      _semanticLoading = false;
    });
  }

  // ===============================
  // HIGHLIGHT HELPERS
  // ===============================
  Widget highlightText(String text) {
    if (_searchText.isEmpty) return Text(text);
    final keys = _searchText.split(RegExp(r'\s+'));

    List<TextSpan> spans = [TextSpan(text: text)];
    for (final k in keys) {
      if (k.isEmpty) continue;
      spans = _applyHighlight(spans, k);
    }

    return RichText(
      text: TextSpan(style: const TextStyle(color: Colors.black), children: spans),
    );
  }

  Widget highlightSemanticText(String text, String emotion) {
    final keys = emotionSynonyms[emotion.toLowerCase()] ?? [];
    List<TextSpan> spans = [TextSpan(text: text)];

    for (final k in keys) {
      spans = _applyHighlight(spans, k);
    }

    return RichText(
      text: TextSpan(style: const TextStyle(color: Colors.black), children: spans),
    );
  }

  List<TextSpan> _applyHighlight(List<TextSpan> spans, String keyword) {
    final List<TextSpan> result = [];
    for (final span in spans) {
      final text = span.text ?? "";
      final lower = text.toLowerCase();
      final key = keyword.toLowerCase();

      if (!lower.contains(key)) {
        result.add(span);
        continue;
      }

      final start = lower.indexOf(key);
      final end = start + key.length;

      result.add(TextSpan(text: text.substring(0, start)));
      result.add(TextSpan(
        text: text.substring(start, end),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      result.add(TextSpan(text: text.substring(end)));
    }
    return result;
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final history = _semanticMode ? _semanticResults : filteredHistory;

    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search emotions or meaning…",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    setState(() => _searchText = v);
                    _persistState();
                  },
                  onSubmitted: (_) {
                    if (_semanticMode) _runSemanticSearch();
                  },
                ),
                SwitchListTile(
                  title: const Text("AI Semantic Search"),
                  subtitle: const Text("Search by meaning"),
                  value: _semanticMode,
                  onChanged: (v) {
                    setState(() {
                      _semanticMode = v;
                      _semanticResults.clear();
                    });
                    if (v) _runSemanticSearch();
                  },
                ),
              ],
            ),
          ),
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                h["emotion"].toString().toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: _semanticMode
                                  ? highlightSemanticText(h["text"], h["emotion"])
                                  : highlightText(h["text"]),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("S${h["severity"]}"),
                                  if (_semanticMode)
                                    const Icon(Icons.auto_awesome,
                                        size: 14, color: Colors.deepPurple),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
