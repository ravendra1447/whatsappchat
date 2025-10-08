import 'package:hive/hive.dart';

part 'setting.g.dart';

@HiveType(typeId: 6)
class Setting extends HiveObject {
  @HiveField(0)
  final int settingId;

  @HiveField(1)
  final int userId;

  @HiveField(2)
  final String lastSeenPrivacy;

  @HiveField(3)
  final String profilePhotoPrivacy;

  @HiveField(4)
  final String aboutPrivacy;

  @HiveField(5)
  final bool readReceipts;

  @HiveField(6)
  final bool notificationsEnabled;

  Setting({
    required this.settingId,
    required this.userId,
    this.lastSeenPrivacy = "everyone",
    this.profilePhotoPrivacy = "everyone",
    this.aboutPrivacy = "everyone",
    this.readReceipts = true,
    this.notificationsEnabled = true,
  });
}
