import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize authentication state
  await AuthService.init();

  // ✅ Warm up Render server (prevents first login timeout)
  await ApiClient.warmUpServer();

  runApp(const MentalHealthApp());
}

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "Mental Health App",
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
    );
  }
}
