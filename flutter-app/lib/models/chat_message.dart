import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 0)
enum MessageType {
  @HiveField(0) chat,
  @HiveField(1) file,
  @HiveField(2) image,
  @HiveField(3) join,
  @HiveField(4) leave,
  @HiveField(5) system,
}

@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  @HiveField(0) String messageId;
  @HiveField(1) String roomId;
  @HiveField(2) String senderId;
  @HiveField(3) String senderName;
  @HiveField(4) String content;
  @HiveField(5) MessageType type;
  @HiveField(6) DateTime timestamp;
  @HiveField(7) String? fileUrl;
  @HiveField(8) String? fileName;
  @HiveField(9) String? fileSize;
  @HiveField(10) String? fileType;
  @HiveField(11) String status; // SENT, SENDING, FAILED

  ChatMessage({
    required this.messageId,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.status = 'SENT',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'] ?? '',
      roomId: json['roomId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      type: _parseType(json['type']),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      fileType: json['fileType'],
      status: json['status'] ?? 'SENT',
    );
  }

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'roomId': roomId,
    'senderId': senderId,
    'senderName': senderName,
    'content': content,
    'type': type.name.toUpperCase(),
    'timestamp': timestamp.toIso8601String(),
    if (fileUrl != null) 'fileUrl': fileUrl,
    if (fileName != null) 'fileName': fileName,
    if (fileSize != null) 'fileSize': fileSize,
    if (fileType != null) 'fileType': fileType,
    'status': status,
  };

  static MessageType _parseType(dynamic t) {
    switch (t?.toString().toUpperCase()) {
      case 'FILE':   return MessageType.file;
      case 'IMAGE':  return MessageType.image;
      case 'JOIN':   return MessageType.join;
      case 'LEAVE':  return MessageType.leave;
      case 'SYSTEM': return MessageType.system;
      default:       return MessageType.chat;
    }
  }

  bool get isFile  => type == MessageType.file;
  bool get isImage => type == MessageType.image ||
      (fileType?.startsWith('image/') ?? false);
  bool get isSystem => type == MessageType.system ||
      type == MessageType.join || type == MessageType.leave;

  @override
  String toString() => 'ChatMessage($messageId, $senderName, $content)';
}
