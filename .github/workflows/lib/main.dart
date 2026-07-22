import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: আপনার Supabase URL এবং Anon Key দিয়ে নিচের দুটি মান পরিবর্তন করুন
  await Supabase.initialize(
    url: 'https://bgdaecclrpupfhsfstso.supabase.co',
    anonKey: 'sb_publishable_galw0ZH6gArXlQJ-Weg9YQ_UdMGLxGy',
  );

  runApp(const MCQVandarApp());
}

class MCQVandarApp extends StatelessWidget {
  const MCQVandarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCQ Vandar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCQ Vandar App'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                'এমসিকিউ ভান্ডার অ্যাপে স্বাগতম!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'ডাটাবেজ ও কানেকশন সফলভাবে সেটআপ করা হয়েছে।',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
