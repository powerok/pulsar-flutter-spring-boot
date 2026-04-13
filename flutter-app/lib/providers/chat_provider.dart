import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../services/api_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/notification_service.dart';

// ── 전역 서비스 프로바이더 ──────────────────────
final apiServiceProvider = Provider((ref) => ApiService());

final wsServiceProvider = Provider((ref) {
  final service = ChatWebSocketService();
  ref.onDispose(service.disconnect);
  return service;
});

// ── 유저 프로필 ───────────────────────────────
class UserProfile {
  final String id;
  final String name;
  final int colorIndex;

  const UserProfile({
    required this.id,
    required this.name,
    required this.colorIndex,
  });

  UserProfile copyWith({String? name, int? colorIndex}) => UserProfile(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
  );
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier() : super(null) {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    final id   = box.get('userId') as String?;
    final name = box.get('userName') as String?;
    final ci   = box.get('colorIndex') as int? ?? 0;
    if (id != null && name != null) {
      state = UserProfile(id: id, name: name, colorIndex: ci);
    }
  }

  Future<void> setProfile(String name, int colorIndex) async {
    final box = Hive.box('settings');
    final id = box.get('userId') as String? ?? const Uuid().v4();
    await box.put('userId', id);
    await box.put('userName', name);
    await box.put('colorIndex', colorIndex);
    state = UserProfile(id: id, name: name, colorIndex: colorIndex);
  }
}

// ── 채팅방 목록 ────────────────────────────────
final roomListProvider = StateNotifierProvider<RoomListNotifier, List<ChatRoom>>((ref) {
  return RoomListNotifier();
});

class RoomListNotifier extends StateNotifier<List<ChatRoom>> {
  RoomListNotifier() : super(ChatRoom.defaults);

  void addRoom(String name, String icon) {
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    if (!state.any((r) => r.id == id)) {
      state = [...state, ChatRoom(id: id, name: name, icon: icon)];
    }
  }

  void incrementUnread(String roomId) {
    state = state.map((r) {
      if (r.id == roomId) r.unreadCount++;
      return r;
    }).toList();
  }

  void clearUnread(String roomId) {
    state = state.map((r) {
      if (r.id == roomId) r.unreadCount = 0;
      return r;
    }).toList();
  }

  void updateLastMessage(String roomId, String msg, DateTime time) {
    state = state.map((r) {
      if (r.id == roomId) {
        r.lastMessage = msg;
        r.lastMessageTime = time;
      }
      return r;
    }).toList();
  }
}

// ── 현재 채팅방 ────────────────────────────────
final currentRoomProvider = StateProvider<String?>((ref) => null);

// ── 메시지 목록 ────────────────────────────────
final messagesProvider =
    StateNotifierProvider<MessagesNotifier, Map<String, List<ChatMessage>>>((ref) {
  return MessagesNotifier(ref);
});

class MessagesNotifier extends StateNotifier<Map<String, List<ChatMessage>>> {
  final Ref ref;
  final Box<ChatMessage> _box = Hive.box<ChatMessage>('messages');

  MessagesNotifier(this.ref) : super({}) {
    _loadFromCache();
    _setupWsListener();
  }

  void _loadFromCache() {
    try {
      final Map<String, List<ChatMessage>> cached = {};
      final List<dynamic> systemKeys = [];

      // values iterator가 index 기반 getAt보다 빠를 수 있음
      final allMessages = _box.values.toList();
      final allKeys = _box.keys.toList();

      for (var i = 0; i < allMessages.length; i++) {
        final msg = allMessages[i];
        if (msg.isSystem) {
          systemKeys.add(allKeys[i]);
          continue;
        }
        cached.putIfAbsent(msg.roomId, () => []).add(msg);
      }

      // 시스템 메시지가 너무 많으면 백그라운드에서 비동기 삭제 (UI 블로킹 방지)
      if (systemKeys.isNotEmpty) {
        Future.microtask(() => _box.deleteAll(systemKeys));
      }

      // 각 방별로 시간순 정렬 (데이터가 많을 경우 대비하여 최신 50개만 유지 등 고려 가능)
      cached.forEach((_, list) {
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      state = cached;
    } catch (e) {
      print('[Cache Load Error] $e');
      state = {};
    }
  }

  void _setupWsListener() {
    final ws = ref.read(wsServiceProvider);
    ws.onMessageReceived = (msg) => addMessage(msg);
  }

  void addMessage(ChatMessage msg) {
    final current = ref.read(currentRoomProvider);
    final roomMessages = List<ChatMessage>.from(state[msg.roomId] ?? []);

    // 1. 중복 제거 (ID 기준)
    if (roomMessages.any((m) => m.messageId == msg.messageId)) return;

    // 2. 중복 제거 (내용/시간 기준 - 낙관적 업데이트 대응)
    // 폰에서 보낸 메시지가 서버를 거쳐 다시 들어올 때 ID가 달라질 수 있음
    final sendingIdx = roomMessages.indexWhere((m) =>
        m.status == 'SENDING' &&
        m.senderId == msg.senderId &&
        m.content == msg.content &&
        (m.timestamp.millisecondsSinceEpoch - msg.timestamp.millisecondsSinceEpoch).abs() < 5000);

    if (sendingIdx != -1) {
      // 기존 'SENDING' 메시지를 서버에서 온 정식 메시지로 교체
      roomMessages[sendingIdx] = msg;
    } else {
      roomMessages.add(msg);
    }

    state = {...state, msg.roomId: roomMessages};

    // 3. Hive 캐시 저장 (시스템 메시지는 저장 제외)
    if (!msg.isSystem) {
      _box.put(msg.messageId, msg);
    }

    // 방 목록 업데이트
    ref.read(roomListProvider.notifier)
        .updateLastMessage(msg.roomId, msg.content, msg.timestamp);

    // 다른 방 메시지면 unread++
    if (current != msg.roomId && !msg.isSystem) {
      ref.read(roomListProvider.notifier).incrementUnread(msg.roomId);
    }
  }

  void updateMessageStatus(String roomId, String messageId, String status) {
    final roomMessages = List<ChatMessage>.from(state[roomId] ?? []);
    final idx = roomMessages.indexWhere((m) => m.messageId == messageId);
    if (idx != -1) {
      roomMessages[idx].status = status;
      state = {...state, roomId: roomMessages};
      // Hive에도 업데이트 된 상태 저장
      if (!roomMessages[idx].isSystem) {
        _box.put(messageId, roomMessages[idx]);
      }
    }
  }

  void clearRoom(String roomId) {
    state = {...state, roomId: []};
  }

  List<ChatMessage> getMessages(String roomId) {
    return state[roomId] ?? [];
  }
}

// ── WebSocket 연결 상태 ────────────────────────
final wsConnectedProvider = StateProvider<bool>((ref) => false);
final backendHealthProvider = StateProvider<bool>((ref) => false);
final uploadProgressProvider = StateProvider<double>((ref) => 0.0);

// ── 채팅 컨트롤러 ──────────────────────────────
final chatControllerProvider = Provider((ref) => ChatController(ref));

class ChatController {
  final Ref ref;

  ChatController(this.ref);

  ApiService get _api => ref.read(apiServiceProvider);
  ChatWebSocketService get _ws => ref.read(wsServiceProvider);

  UserProfile? get profile => ref.read(userProfileProvider);
  String? get currentRoom => ref.read(currentRoomProvider);

  /// 채팅방 입장
  Future<void> joinRoom(String roomId) async {
    ref.read(currentRoomProvider.notifier).state = roomId;
    ref.read(roomListProvider.notifier).clearUnread(roomId);
    
    // 1. 서버에서 과거 내역 가져오기
    final history = await _api.getChatHistory(roomId);
    for (final msg in history) {
      ref.read(messagesProvider.notifier).addMessage(msg);
    }

    // 2. WebSocket 구독
    _ws.subscribeToRoom(roomId);

    // 3. 입장 메시지
    _addLocalSystemMessage(roomId, '${profile?.name}님이 입장했습니다.');
  }

  /// 메시지 전송
  Future<void> sendMessage(String content) async {
    final p = profile;
    final roomId = currentRoom;
    if (p == null || roomId == null || content.trim().isEmpty) return;

    final msg = ChatMessage(
      messageId: const Uuid().v4(),
      roomId: roomId,
      senderId: p.id,
      senderName: p.name,
      content: content.trim(),
      type: MessageType.chat,
      timestamp: DateTime.now(),
      status: 'SENDING',
    );

    // 낙관적 업데이트
    ref.read(messagesProvider.notifier).addMessage(msg);

    final messageId = await _api.sendMessage(
      roomId: roomId,
      senderId: p.id,
      senderName: p.name,
      content: content.trim(),
      messageId: msg.messageId,
    );

    if (messageId != null) {
      ref.read(messagesProvider.notifier).updateMessageStatus(roomId, msg.messageId, 'SENT');
    } else {
      ref.read(messagesProvider.notifier).updateMessageStatus(roomId, msg.messageId, 'FAILED');
    }
  }

  /// 파일 업로드 및 전송
  Future<void> sendFile(String filePath, String? contentType) async {
    final p = profile;
    final roomId = currentRoom;
    if (p == null || roomId == null) return;

    ref.read(uploadProgressProvider.notifier).state = 0.1;

    final result = await _api.uploadFile(
      filePath: filePath,
      roomId: roomId,
      senderId: p.id,
      senderName: p.name,
      onProgress: (sent, total) {
        ref.read(uploadProgressProvider.notifier).state = sent / total;
      },
    );

    ref.read(uploadProgressProvider.notifier).state = 0.0;

    if (result == null) {
      _addLocalSystemMessage(roomId, '⚠ 파일 업로드 실패');
    }
  }

  void _addLocalSystemMessage(String roomId, String content) {
    final msg = ChatMessage(
      messageId: 'sys-${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: 'system',
      senderName: 'System',
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
    );
    ref.read(messagesProvider.notifier).addMessage(msg);
  }

  /// WebSocket 초기화
  void initWebSocket() {
    final ws = ref.read(wsServiceProvider);
    ws.onConnectionChanged = (connected) {
      ref.read(wsConnectedProvider.notifier).state = connected;
    };
    ws.connect();
  }

  /// 백엔드 헬스 체크
  Future<void> checkHealth() async {
    try {
      final ok = await _api.checkHealth();
      ref.read(backendHealthProvider.notifier).state = ok;
    } catch (e) {
       print('[Health Check Error] $e');
       ref.read(backendHealthProvider.notifier).state = false;
    }
  }
}
