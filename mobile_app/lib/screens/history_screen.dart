import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/predict_service.dart';

/// ===============================
/// EMOTION SYNONYMS (EN / TE / HI)
/// ===============================
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
  // LOAD HISTORY (SAFE)
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
        SnackBar(
          content: Text(
            e.toString().replaceAll("Exception:", "").trim(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===============================
  // KEYWORD SEARCH
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
  // 🧠 AI SEMANTIC SEARCH (OPTIONAL)
  // ===============================
  Future<void> _runSemanticSearch() async {
    if (_searchText.trim().isEmpty) return;

    setState(() => _semanticLoading = true);

    try {
      // ⚠️ Semantic search may not exist
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Semantic search not available"),
        ),
      );
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search emotion, severity, meaning…",
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Confidence: ${(h["confidence"] * 100).toStringAsFixed(1)}%",
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("S${h["severity"]}"),
                                  if (_semanticMode)
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: Colors.deepPurple,
                                    ),
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
