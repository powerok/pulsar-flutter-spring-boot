import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/chat_message.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 날짜 포맷팅 초기화 (한국어)
  await initializeDateFormatting('ko', null);

  // Hive 초기화 (오프라인 캐시)
  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(MessageTypeAdapter());
  await Hive.openBox<ChatMessage>('messages');
  await Hive.openBox('settings');

  // 푸시 알림 초기화
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: PulsarChatApp(),
    ),
  );
}

class PulsarChatApp extends ConsumerWidget {
  const PulsarChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Pulsar Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1D27),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
