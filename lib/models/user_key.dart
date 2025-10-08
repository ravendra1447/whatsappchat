import 'package:hive/hive.dart';

part 'user_key.g.dart';

@HiveType(typeId: 5)
class UserKey extends HiveObject {
  @HiveField(0)
  final int keyId;

  @HiveField(1)
  final int userId;

  @HiveField(2)
  final String publicKey;

  @HiveField(3)
  final String privateKey;

  UserKey({
    required this.keyId,
    required this.userId,
    required this.publicKey,
    required this.privateKey,
  });
}
