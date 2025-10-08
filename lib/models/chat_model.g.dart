// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 0;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      messageId: fields[0] as String,
      chatId: fields[1] as int,
      senderId: fields[2] as int,
      receiverId: fields[3] as int,
      messageContent: fields[4] as String,
      messageType: fields[5] as String,
      isRead: fields[6] as int,
      timestamp: fields[7] as DateTime,
      isDelivered: fields[8] as int,
      senderName: fields[9] as String?,
      receiverName: fields[10] as String?,
      senderPhoneNumber: fields[11] as String?,
      receiverPhoneNumber: fields[12] as String?,
      isDeletedSender: fields[13] as int,
      isDeletedReceiver: fields[14] as int,
      thumbnail: fields[15] as Uint8List?,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.messageId)
      ..writeByte(1)
      ..write(obj.chatId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.receiverId)
      ..writeByte(4)
      ..write(obj.messageContent)
      ..writeByte(5)
      ..write(obj.messageType)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.timestamp)
      ..writeByte(8)
      ..write(obj.isDelivered)
      ..writeByte(13)
      ..write(obj.isDeletedSender)
      ..writeByte(14)
      ..write(obj.isDeletedReceiver)
      ..writeByte(15)
      ..write(obj.thumbnail)
      ..writeByte(9)
      ..write(obj.senderName)
      ..writeByte(10)
      ..write(obj.receiverName)
      ..writeByte(11)
      ..write(obj.senderPhoneNumber)
      ..writeByte(12)
      ..write(obj.receiverPhoneNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
