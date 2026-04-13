// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 1;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      messageId: fields[0] as String,
      roomId: fields[1] as String,
      senderId: fields[2] as String,
      senderName: fields[3] as String,
      content: fields[4] as String,
      type: fields[5] as MessageType,
      timestamp: fields[6] as DateTime,
      fileUrl: fields[7] as String?,
      fileName: fields[8] as String?,
      fileSize: fields[9] as String?,
      fileType: fields[10] as String?,
      status: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.messageId)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.senderName)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.fileUrl)
      ..writeByte(8)
      ..write(obj.fileName)
      ..writeByte(9)
      ..write(obj.fileSize)
      ..writeByte(10)
      ..write(obj.fileType)
      ..writeByte(11)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageTypeAdapter extends TypeAdapter<MessageType> {
  @override
  final int typeId = 0;

  @override
  MessageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageType.chat;
      case 1:
        return MessageType.file;
      case 2:
        return MessageType.image;
      case 3:
        return MessageType.join;
      case 4:
        return MessageType.leave;
      case 5:
        return MessageType.system;
      default:
        return MessageType.chat;
    }
  }

  @override
  void write(BinaryWriter writer, MessageType obj) {
    switch (obj) {
      case MessageType.chat:
        writer.writeByte(0);
        break;
      case MessageType.file:
        writer.writeByte(1);
        break;
      case MessageType.image:
        writer.writeByte(2);
        break;
      case MessageType.join:
        writer.writeByte(3);
        break;
      case MessageType.leave:
        writer.writeByte(4);
        break;
      case MessageType.system:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
