import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import 'room_list_screen.dart';

const _colors = [
  Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43D98C),
  Color(0xFFFFD166), Color(0xFF06D6A0), Color(0xFFEF476F),
  Color(0xFF118AB2), Color(0xFFF77F00), Color(0xFFE63946),
  Color(0xFF457B9D), Color(0xFF2A9D8F), Color(0xFFE9C46A),
];

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  int _selectedColor = 0;
  bool _loading = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);

    await ref.read(userProfileProvider.notifier)
        .setProfile(_nameCtrl.text.trim(), _selectedColor);

    // WebSocket & 헬스 체크 초기화
    ref.read(chatControllerProvider).initWebSocket();
    ref.read(chatControllerProvider).checkHealth();

    if (mounted) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const RoomListScreen()));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _colors[_selectedColor],
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: _colors[_selectedColor].withOpacity(0.4),
                      blurRadius: 20, spreadRadius: 2,
                    )],
                  ),
                  child: Center(
                    child: Text(
                      _nameCtrl.text.isEmpty ? '?' : _nameCtrl.text[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text('프로필 설정',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text('채팅을 시작하기 전에 닉네임을 설정하세요.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 28),

              // 닉네임 입력
              _label('닉네임'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                maxLength: 20,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '사용할 이름을 입력하세요',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: const Color(0xFF1A1D27),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E3350)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E3350)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                ),
              ),
              const SizedBox(height: 24),

              // 색상 선택
              _label('아바타 색상'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: List.generate(_colors.length, (i) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == i ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: _selectedColor == i ? [
                        BoxShadow(color: _colors[i].withOpacity(0.6),
                            blurRadius: 12, spreadRadius: 1)
                      ] : [],
                    ),
                    child: _selectedColor == i
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                )),
              ),
              const SizedBox(height: 40),

              // 시작 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _nameCtrl.text.trim().isEmpty || _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('시작하기 🚀',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(color: Colors.white.withOpacity(0.6),
          fontSize: 12, fontWeight: FontWeight.w700,
          letterSpacing: 1, decoration: TextDecoration.none));
}
