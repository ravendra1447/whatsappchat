// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactAdapter extends TypeAdapter<Contact> {
  @override
  final int typeId = 4;

  @override
  Contact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contact(
      contactId: fields[0] as int,
      ownerUserId: fields[1] as int,
      contactName: fields[2] as String,
      contactPhone: fields[3] as String,
      isOnApp: fields[4] as bool,
      appUserId: fields[5] as int?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Contact obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.contactId)
      ..writeByte(1)
      ..write(obj.ownerUserId)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.contactPhone)
      ..writeByte(4)
      ..write(obj.isOnApp)
      ..writeByte(5)
      ..write(obj.appUserId)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
