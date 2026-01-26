import 'package:flutter/material.dart';
import '../services/predict_service.dart';

enum AppLanguage { english, telugu, hindi }

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<List<dynamic>> _historyFuture;
  AppLanguage _language = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _historyFuture = PredictService.fetchHistory();
  }

  // ============================
  // LANGUAGE TEXTS
  // ============================
  String t(String en, String te, String hi) {
    switch (_language) {
      case AppLanguage.telugu:
        return te;
      case AppLanguage.hindi:
        return hi;
      default:
        return en;
    }
  }

  // ============================
  // HELPERS
  // ============================
  String emoji(String emotion) {
    switch (emotion) {
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

  String riskLevel(int highRiskCount) {
    if (highRiskCount >= 3) return "HIGH";
    if (highRiskCount >= 1) return "MODERATE";
    return "LOW";
  }

  Color riskColor(String level) {
    switch (level) {
      case "HIGH":
        return Colors.red;
      case "MODERATE":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  // ============================
  // AI-GENERATED ADVICE
  // ============================
  String aiAdvice(String emotion, String risk) {
    if (risk == "HIGH") {
      return t(
        "Your emotional signals show high risk. Please consider reaching out to a trusted person or mental health professional immediately.",
        "మీ భావోద్వేగాలు అధిక ప్రమాదాన్ని సూచిస్తున్నాయి. దయచేసి నమ్మకమైన వ్యక్తి లేదా మానసిక నిపుణుడిని సంప్రదించండి.",
        "आपकी भावनाएँ उच्च जोखिम दर्शा रही हैं। कृपया किसी भरोसेमंद व्यक्ति या मानसिक स्वास्थ्य विशेषज्ञ से संपर्क करें।",
      );
    }

    if (emotion == "anxiety") {
      return t(
        "You seem stressed lately. Try slow breathing, short walks, and reducing screen time.",
        "మీరు ఇటీవల ఒత్తిడిగా ఉన్నట్లు కనిపిస్తోంది. లోతైన శ్వాసలు, చిన్న నడకలు ఉపశమనం ఇస్తాయి.",
        "आप हाल ही में तनाव में हैं। गहरी साँसें, छोटी सैर और स्क्रीन समय कम करना मदद कर सकता है।",
      );
    }

    if (emotion == "depression") {
      return t(
        "Low mood detected. Writing your thoughts or talking to someone you trust may help.",
        "తక్కువ మూడ్ కనిపిస్తోంది. మీ ఆలోచనలు రాయడం లేదా నమ్మకమైన వ్యక్తితో మాట్లాడటం ఉపయోగపడుతుంది.",
        "कम मनोदशा पाई गई है। अपने विचार लिखना या किसी भरोसेमंद व्यक्ति से बात करना मदद कर सकता है।",
      );
    }

    if (emotion == "happy") {
      return t(
        "You are doing well emotionally. Keep maintaining healthy routines.",
        "మీ భావోద్వేగ స్థితి మంచిగా ఉంది. ఈ అలవాట్లను కొనసాగించండి.",
        "आप भावनात्मक रूप से अच्छा कर रहे हैं। स्वस्थ आदतें बनाए रखें।",
      );
    }

    return t(
      "Regular emotional check-ins help improve self-awareness and balance.",
      "నియమిత భావోద్వేగ పరిశీలన స్వీయ అవగాహనను పెంచుతుంది.",
      "नियमित भावनात्मक जांच आत्म-जागरूकता बढ़ाती है।",
    );
  }

  // ============================
  // UI
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t("Insights", "విశ్లేషణ", "विश्लेषण")),
        actions: [
          PopupMenuButton<AppLanguage>(
            onSelected: (l) => setState(() => _language = l),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: AppLanguage.english, child: Text("English")),
              PopupMenuItem(
                  value: AppLanguage.telugu, child: Text("తెలుగు")),
              PopupMenuItem(
                  value: AppLanguage.hindi, child: Text("हिंदी")),
            ],
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return Center(
              child: Text(t(
                "No insights available yet",
                "ఇప్పటికీ విశ్లేషణ లేదు",
                "अभी कोई विश्लेषण उपलब्ध नहीं है",
              )),
            );
          }

          final totalEntries = history.length;

          final avgSeverity =
              history.map((e) => (e["severity"] ?? 0) as int).reduce((a, b) => a + b) /
                  totalEntries;

          final emotionCount = <String, int>{};
          for (var h in history) {
            final e = h["emotion"] ?? "unknown";
            emotionCount[e] = (emotionCount[e] ?? 0) + 1;
          }

          final dominantEmotion =
              emotionCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

          final highRiskCount =
              history.where((h) => (h["severity"] ?? 0) >= 4).length;

          final risk = riskLevel(highRiskCount);
          final stabilityScore =
              (100 - (avgSeverity * 15)).clamp(0, 100).toInt();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _summaryCard(
                      emoji(dominantEmotion),
                      t("Top Emotion", "ప్రధాన భావం", "मुख्य भावना"),
                      dominantEmotion.toUpperCase(),
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(
                      "⚡",
                      t("Avg Severity", "సగటు తీవ్రత", "औसत तीव्रता"),
                      avgSeverity.toStringAsFixed(1),
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(
                      "📊",
                      t("Entries", "ఎంట్రీలు", "प्रविष्टियाँ"),
                      totalEntries.toString(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _infoCard(
                  icon: "📈",
                  title: t("Mood Stability", "మూడ్ స్థిరత్వం", "मूड स्थिरता"),
                  text: t(
                    "Your mood stability score is $stabilityScore / 100.",
                    "మీ మూడ్ స్థిరత్వ స్కోరు $stabilityScore / 100.",
                    "आपका मूड स्थिरता स्कोर $stabilityScore / 100 है।",
                  ),
                ),

                const SizedBox(height: 16),

                _riskCard(risk, highRiskCount),

                const SizedBox(height: 16),

                _infoCard(
                  icon: "🤖",
                  title: t("AI Advice", "AI సలహా", "AI सलाह"),
                  text: aiAdvice(dominantEmotion, risk),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================
  // UI COMPONENTS
  // ============================
  Widget _summaryCard(String icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.deepPurple.withOpacity(0.08),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(
      {required String icon,
      required String title,
      required String text}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.blue.withOpacity(0.08),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskCard(String risk, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: riskColor(risk).withOpacity(0.12),
      ),
      child: Row(
        children: [
          const Text("🚨", style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t(
                "Risk Level: $risk ($count high severity)",
                "ప్రమాద స్థాయి: $risk ($count అధిక తీవ్రత)",
                "जोखिम स्तर: $risk ($count उच्च तीव्रता)",
              ),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: riskColor(risk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
