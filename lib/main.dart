import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/features/home/home_view.dart';
import 'package:logbook_app_001/features/vision/models/translation_log.dart';
import 'package:logbook_app_001/features/vision/widgets/translation_history_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Hive.initFlutter();
  Hive.registerAdapter(LogModelAdapter());
  Hive.registerAdapter(TranslationLogAdapter());
  await Hive.openBox<LogModel>('offline_logs');
  await Hive.openBox<TranslationLog>('translation_logs');

  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BISINDO Edge Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF06B6D4),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeView(),
      routes: {
        '/riwayat': (context) => const TranslationHistoryView(),
      },
    );
  }
}