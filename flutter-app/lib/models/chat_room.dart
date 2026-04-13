class ChatRoom {
  final String id;
  final String name;
  final String icon;
  int memberCount;
  int unreadCount;
  String? lastMessage;
  DateTime? lastMessageTime;

  ChatRoom({
    required this.id,
    required this.name,
    required this.icon,
    this.memberCount = 0,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageTime,
  });

  String get topic => 'persistent://public/chat/room-$id';

  static List<ChatRoom> get defaults => [
    ChatRoom(id: 'general', name: '일반',  icon: '💬', memberCount: 0),
    ChatRoom(id: 'random',  name: '자유',  icon: '🎲', memberCount: 0),
    ChatRoom(id: 'tech',    name: '기술',  icon: '💻', memberCount: 0),
    ChatRoom(id: 'design',  name: '디자인', icon: '🎨', memberCount: 0),
  ];
}
