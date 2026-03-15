import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CrisisSupportScreen extends StatelessWidget {
  final Map data;

  const CrisisSupportScreen({super.key, required this.data});

  Future<void> callNumber(String phone) async {
    final Uri url = Uri(scheme: "tel", path: phone);
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {

    final helplines = data["helplines"] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Support Available"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            const Icon(
              Icons.favorite,
              size: 80,
              color: Colors.red,
            ),

            const SizedBox(height: 20),

            Text(
              data["message"] ?? "You are not alone.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: ListView.builder(
                itemCount: helplines.length,
                itemBuilder: (context, i) {

                  final h = helplines[i];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(h["name"]),
                      subtitle: Text(h["phone"]),
                      trailing: const Icon(Icons.call),
                      onTap: () => callNumber(h["phone"]),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}