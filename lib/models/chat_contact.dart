// lib/models/chat_contact.dart

class ChatContact {
  // Chat list के लिए आवश्यक Properties
  final int id; // The other user's appUserId
  final String name;
  final String? lastMessage;
  final DateTime lastMessageTime;
  final int? chatId;
  final String? phoneNumber;

  // New property for unread count
  int unreadCount;

  ChatContact({
    required this.id,
    required this.name,
    this.lastMessage,
    required this.lastMessageTime,
    this.chatId,
    this.phoneNumber,
    this.unreadCount = 0,
  });

  // 🟢 toJson method जोड़ा गया ताकि यह JSON में एन्कोड हो सके
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,

      'lastMessage': lastMessage,
      // DateTime को String फॉर्मेट में बदलने के लिए
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'chatId': chatId,
      'phoneNumber': phoneNumber,
      'unreadCount': unreadCount,
    };
  }
}
