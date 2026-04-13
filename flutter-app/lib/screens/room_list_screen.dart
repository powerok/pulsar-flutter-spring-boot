import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';

const _avatarColors = [
  Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43D98C),
  Color(0xFFFFD166), Color(0xFF06D6A0), Color(0xFFEF476F),
  Color(0xFF118AB2), Color(0xFFF77F00), Color(0xFFE63946),
  Color(0xFF457B9D), Color(0xFF2A9D8F), Color(0xFFE9C46A),
];

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. WebSocket 연결 (약간의 여유를 줌)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      ref.read(chatControllerProvider).initWebSocket();
      
      // 2. 헬스 체크 (시간차를 두고 실행)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ref.read(chatControllerProvider).checkHealth();
    });
  }

  void _addRoom() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('새 채팅방 만들기', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '채팅방 이름',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true, fillColor: const Color(0xFF22263A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref.read(roomListProvider.notifier).addRoom(ctrl.text.trim(), '🚀');
                Navigator.pop(context);
              }
            },
            child: const Text('만들기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile   = ref.watch(userProfileProvider);
    final rooms     = ref.watch(roomListProvider);
    final wsOk      = ref.watch(wsConnectedProvider);
    final backendOk = ref.watch(backendHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('⚡', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Pulsar Chat', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          // 연결 상태 표시
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: wsOk
                  ? const Color(0xFF43D98C).withOpacity(0.15)
                  : const Color(0xFFFF6584).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              wsOk ? '● 연결됨' : '○ 연결 중',
              style: TextStyle(
                color: wsOk ? const Color(0xFF43D98C) : const Color(0xFFFF6584),
                fontSize: 12, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 프로필 아바타
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _avatarColors[profile.colorIndex % _avatarColors.length],
                child: Text(
                  profile.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 상단 통계 카드
          if (!backendOk)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('⚠', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Backend 서버에 연결할 수 없습니다. localhost:8081을 확인하세요.',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              itemBuilder: (ctx, i) {
                final room = rooms[i];
                return _RoomTile(room: room, onTap: () {
                  ref.read(chatControllerProvider).joinRoom(room.id);
                  Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => ChatScreen(room: room)));
                });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoom,
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onTap;

  const _RoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E3350)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF22263A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(room.icon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(room.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(
          room.lastMessage ?? '${room.topic}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
        trailing: room.unreadCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6584),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${room.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              )
            : const Icon(Icons.chevron_right, color: Color(0xFF2E3350)),
      ),
    );
  }
}
