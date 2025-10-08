// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingAdapter extends TypeAdapter<Setting> {
  @override
  final int typeId = 6;

  @override
  Setting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Setting(
      settingId: fields[0] as int,
      userId: fields[1] as int,
      lastSeenPrivacy: fields[2] as String,
      profilePhotoPrivacy: fields[3] as String,
      aboutPrivacy: fields[4] as String,
      readReceipts: fields[5] as bool,
      notificationsEnabled: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Setting obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.settingId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.lastSeenPrivacy)
      ..writeByte(3)
      ..write(obj.profilePhotoPrivacy)
      ..writeByte(4)
      ..write(obj.aboutPrivacy)
      ..writeByte(5)
      ..write(obj.readReceipts)
      ..writeByte(6)
      ..write(obj.notificationsEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
