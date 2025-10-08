// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_key.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserKeyAdapter extends TypeAdapter<UserKey> {
  @override
  final int typeId = 5;

  @override
  UserKey read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserKey(
      keyId: fields[0] as int,
      userId: fields[1] as int,
      publicKey: fields[2] as String,
      privateKey: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserKey obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.keyId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.publicKey)
      ..writeByte(3)
      ..write(obj.privateKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserKeyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
