// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatAdapter extends TypeAdapter<Chat> {
  @override
  final int typeId = 3;

  @override
  Chat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chat(
      chatId: fields[0] as int,
      userId: fields[1] as int,
      contactId: fields[2] as int,
      lastMessage: fields[3] as String?,
      lastMessageTime: fields[4] as DateTime?,
      unreadCount: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Chat obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.chatId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.contactId)
      ..writeByte(3)
      ..write(obj.lastMessage)
      ..writeByte(4)
      ..write(obj.lastMessageTime)
      ..writeByte(5)
      ..write(obj.unreadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
