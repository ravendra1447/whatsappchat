// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_setting.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileSettingAdapter extends TypeAdapter<ProfileSetting> {
  @override
  final int typeId = 0;

  @override
  ProfileSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfileSetting(
      id: fields[0] as int?,
      userId: fields[1] as int?,
      profileImage: fields[2] as String?,
      name: fields[3] as String?,
      legalBusinessName: fields[4] as String?,
      businessType: fields[5] as String?,
      businessCategory: fields[6] as String?,
      gstNo: fields[7] as String?,
      phoneNumber: fields[8] as String?,
      address: fields[9] as String?,
      email: fields[10] as String?,
      website: fields[11] as String?,
      businessDescription: fields[12] as String?,
      about: fields[13] as String?,
      upiQrCode: fields[14] as String?,
      userPhone: fields[15] as String?,
      userName: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileSetting obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.profileImage)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.legalBusinessName)
      ..writeByte(5)
      ..write(obj.businessType)
      ..writeByte(6)
      ..write(obj.businessCategory)
      ..writeByte(7)
      ..write(obj.gstNo)
      ..writeByte(8)
      ..write(obj.phoneNumber)
      ..writeByte(9)
      ..write(obj.address)
      ..writeByte(10)
      ..write(obj.email)
      ..writeByte(11)
      ..write(obj.website)
      ..writeByte(12)
      ..write(obj.businessDescription)
      ..writeByte(13)
      ..write(obj.about)
      ..writeByte(14)
      ..write(obj.upiQrCode)
      ..writeByte(15)
      ..write(obj.userPhone)
      ..writeByte(16)
      ..write(obj.userName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
