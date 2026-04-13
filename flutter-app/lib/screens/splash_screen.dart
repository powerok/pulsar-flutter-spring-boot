import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import 'profile_setup_screen.dart';
import 'room_list_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();

    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    final profile = ref.read(userProfileProvider);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => profile != null
            ? const RoomListScreen()
            : const ProfileSetupScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pulsar Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apache Pulsar 기반 실시간 메시징',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
