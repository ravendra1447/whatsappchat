import 'package:hive/hive.dart';

part 'chat.g.dart';

@HiveType(typeId: 3)
class Chat extends HiveObject {
  @HiveField(0)
  final int chatId;

  @HiveField(1)
  final int userId;

  @HiveField(2)
  final int contactId;

  @HiveField(3)
  final String? lastMessage;

  @HiveField(4)
  final DateTime? lastMessageTime;

  @HiveField(5)
  final int unreadCount;

  Chat({
    required this.chatId,
    required this.userId,
    required this.contactId,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });
}
