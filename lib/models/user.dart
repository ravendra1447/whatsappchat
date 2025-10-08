import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User extends HiveObject {
  @HiveField(0)
  final int userId;

  @HiveField(1)
  final String phoneNumber;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? profilePhotoUrl;

  @HiveField(4)
  final String? about;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  User({
    required this.userId,
    required this.phoneNumber,
    required this.name,
    this.profilePhotoUrl,
    this.about,
    required this.createdAt,
    required this.updatedAt,
  });
}
