import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_message.dart';

typedef MessageCallback = void Function(ChatMessage message);
typedef ConnectionCallback = void Function(bool connected);

class ChatWebSocketService {
  static const String _wsUrl = 'ws://10.0.2.2:8081/ws-native';
  // SockJS 엔드포인트: 'http://10.0.2.2:8081/ws'

  late StompClient _client;
  final Map<String, StompUnsubscribe> _subscriptions = {};

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  ConnectionCallback? onConnectionChanged;
  MessageCallback? onMessageReceived;

  void connect() {
    _client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: (frame) {
          print('[STOMP] 에러: ${frame.body}');
          _isConnected = false;
          onConnectionChanged?.call(false);
        },
        onWebSocketError: (error) {
          print('[WS] 에러: $error');
          _isConnected = false;
          onConnectionChanged?.call(false);
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );
    _client.activate();
    print('[WS] WebSocket 연결 시도...');
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    print('[WS] STOMP 연결 성공');
    onConnectionChanged?.call(true);
  }

  void _onDisconnect(StompFrame frame) {
    _isConnected = false;
    print('[WS] STOMP 연결 해제');
    onConnectionChanged?.call(false);
  }

  /// 채팅방 구독
  void subscribeToRoom(String roomId) {
    if (!_isConnected) return;
    if (_subscriptions.containsKey(roomId)) return; // 이미 구독 중

    final destination = '/topic/chat/$roomId';
    final unsub = _client.subscribe(
      destination: destination,
      callback: (frame) {
        if (frame.body != null) {
          try {
            final json = jsonDecode(frame.body!);
            final msg = ChatMessage.fromJson(json);
            onMessageReceived?.call(msg);
          } catch (e) {
            print('[WS] 메시지 파싱 오류: $e');
          }
        }
      },
    );
    _subscriptions[roomId] = unsub;
    print('[WS] 채팅방 구독: $destination');
  }

  /// 채팅방 구독 취소
  void unsubscribeFromRoom(String roomId) {
    _subscriptions[roomId]?.call();
    _subscriptions.remove(roomId);
    print('[WS] 구독 취소: $roomId');
  }

  /// STOMP를 통한 메시지 전송
  void sendMessage(ChatMessage message) {
    if (!_isConnected) {
      print('[WS] 연결되지 않아 전송 불가');
      return;
    }
    _client.send(
      destination: '/app/chat/${message.roomId}',
      body: jsonEncode(message.toJson()),
    );
  }

  void disconnect() {
    _subscriptions.forEach((_, unsub) => unsub());
    _subscriptions.clear();
    _client.deactivate();
    _isConnected = false;
  }
}
