// lib/models/chat_model.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'chat_model.g.dart';
// Note: आपको यह फाइल 'flutter packages pub run build_runner build' से जनरेट करनी होगी।

@HiveType(typeId: 0) // Message model के लिए typeId 0
class Message extends HiveObject {
  @HiveField(0)
  String messageId;

  @HiveField(1)
  int chatId;

  @HiveField(2)
  int senderId;

  @HiveField(3)
  int receiverId;

  @HiveField(4)
  String messageContent;

  @HiveField(5)
  String messageType;

  @HiveField(6)
  int isRead;

  @HiveField(7)
  DateTime timestamp;

  @HiveField(8)
  int isDelivered;

  // 💡 NEW FIELDS: Deletion Status
  @HiveField(13)
  int isDeletedSender; // 0=false, 1=true

  @HiveField(14)
  int isDeletedReceiver; // 0=false, 1=true

  // ✅ Thumbnail for media preview
  @HiveField(15)
  Uint8List? thumbnail;

  // ✅ NEW: Low quality URL for WhatsApp-style image loading
  @HiveField(16)
  String? lowQualityUrl;

  // Existing optional fields
  @HiveField(9)
  String? senderName;

  @HiveField(10)
  String? receiverName;

  @HiveField(11)
  String? senderPhoneNumber;

  @HiveField(12)
  String? receiverPhoneNumber;

  Message({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.messageContent,
    required this.messageType,
    required this.isRead,
    required this.timestamp,
    required this.isDelivered,
    this.senderName,
    this.receiverName,
    this.senderPhoneNumber,
    this.receiverPhoneNumber,
    // Set default values for new deletion fields
    this.isDeletedSender = 0,
    this.isDeletedReceiver = 0,
    this.thumbnail,
    this.lowQualityUrl, // ✅ NEW: Low quality URL field
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    final dynamic messageIdFromServer = map['message_id'];
    final String parsedMessageId;

    if (messageIdFromServer is int) {
      parsedMessageId = messageIdFromServer.toString();
    } else if (messageIdFromServer is String) {
      parsedMessageId = messageIdFromServer;
    } else {
      parsedMessageId = 'unknown';
    }

    // Deletion fields को मैप से सुरक्षित रूप से पढ़ें
    final int isDeletedSender = map['is_deleted_sender'] as int? ?? 0;
    final int isDeletedReceiver = map['is_deleted_receiver'] as int? ?? 0;

    // ✅ Thumbnail parsing
    Uint8List? parsedThumbnail;
    if (map['thumbnail'] != null && map['thumbnail'] is String) {
      try {
        parsedThumbnail = base64.decode(map['thumbnail'] as String);
      } catch (e) {
        print('❌ Thumbnail decoding error: $e');
      }
    }

    // ✅ NEW: Low quality URL parsing
    final String? parsedLowQualityUrl = map['low_quality_url']?.toString();

    // Time parsing logic
    DateTime parsedTimestamp;
    final dynamic timestampData = map['timestamp'];
    if (timestampData is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampData);
    } else if (timestampData is String) {
      parsedTimestamp = DateTime.tryParse(timestampData) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int);
    }

    return Message(
      messageId: parsedMessageId,
      chatId: map['chat_id'] as int? ?? 0,
      senderId: map['sender_id'] as int? ?? 0,
      receiverId: map['receiver_id'] as int? ?? 0,
      messageContent: map['message_text'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'text',
      isRead: map['is_read'] as int? ?? 0,
      timestamp: parsedTimestamp,
      isDelivered: map['is_delivered'] as int? ?? 0,
      senderName: map['sender_name'] as String?,
      receiverName: map['receiver_name'] as String?,
      senderPhoneNumber: map['sender_phone_number'] as String?,
      receiverPhoneNumber: map['receiver_phone_number'] as String?,
      // New fields mapped
      isDeletedSender: isDeletedSender,
      isDeletedReceiver: isDeletedReceiver,
      thumbnail: parsedThumbnail,
      lowQualityUrl: parsedLowQualityUrl, // ✅ NEW: Low quality URL included
    );
  }

  // ✅ Factory method for JSON (socket data ke liye)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message.fromMap(json);
  }

  // ✅ Convert to Map for sending to server
  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message_text': messageContent,
      'message_type': messageType,
      'is_read': isRead,
      'timestamp': timestamp.toIso8601String(),
      'is_delivered': isDelivered,
      'sender_name': senderName,
      'receiver_name': receiverName,
      'sender_phone_number': senderPhoneNumber,
      'receiver_phone_number': receiverPhoneNumber,
      'is_deleted_sender': isDeletedSender,
      'is_deleted_receiver': isDeletedReceiver,
      'low_quality_url': lowQualityUrl, // ✅ NEW: Include in map
    };
  }

  // ✅ OPTIONAL: Helper method to check if message has thumbnail
  bool get hasThumbnail => thumbnail != null && thumbnail!.isNotEmpty;

  // ✅ NEW: Helper method to check if message has low quality URL
  bool get hasLowQualityUrl => lowQualityUrl != null && lowQualityUrl!.isNotEmpty;

  // ✅ OPTIONAL: Helper method to get display content for media messages
  String get displayContent {
    if (messageType == 'media' || messageType == 'encrypted_media') {
      return hasThumbnail ? '📷 Image' : '📷 Media';
    }
    return messageContent;
  }

  // ✅ NEW: Copy with method for updating fields
  Message copyWith({
    String? messageId,
    int? chatId,
    int? senderId,
    int? receiverId,
    String? messageContent,
    String? messageType,
    int? isRead,
    DateTime? timestamp,
    int? isDelivered,
    int? isDeletedSender,
    int? isDeletedReceiver,
    Uint8List? thumbnail,
    String? lowQualityUrl,
    String? senderName,
    String? receiverName,
    String? senderPhoneNumber,
    String? receiverPhoneNumber,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      messageContent: messageContent ?? this.messageContent,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      isDelivered: isDelivered ?? this.isDelivered,
      senderName: senderName ?? this.senderName,
      receiverName: receiverName ?? this.receiverName,
      senderPhoneNumber: senderPhoneNumber ?? this.senderPhoneNumber,
      receiverPhoneNumber: receiverPhoneNumber ?? this.receiverPhoneNumber,
      isDeletedSender: isDeletedSender ?? this.isDeletedSender,
      isDeletedReceiver: isDeletedReceiver ?? this.isDeletedReceiver,
      thumbnail: thumbnail ?? this.thumbnail,
      lowQualityUrl: lowQualityUrl ?? this.lowQualityUrl,
    );
  }

  @override
  String toString() {
    return 'Message('
        'messageId: $messageId, '
        'chatId: $chatId, '
        'senderId: $senderId, '
        'receiverId: $receiverId, '
        'messageType: $messageType, '
        'isRead: $isRead, '
        'isDelivered: $isDelivered, '
        'hasLowQualityUrl: $hasLowQualityUrl, '
        'timestamp: $timestamp'
        ')';
  }
}

// ✅ Optional: Chat model agar aapke paas hai
@HiveType(typeId: 1)
class Chat extends HiveObject {
  @HiveField(0)
  int chatId;

  @HiveField(1)
  int contactId;

  @HiveField(2)
  List<int> userIds;

  @HiveField(3)
  String chatTitle;

  @HiveField(4)
  DateTime lastMessageTime;

  @HiveField(5)
  String lastMessage;

  Chat({
    required this.chatId,
    required this.contactId,
    required this.userIds,
    required this.chatTitle,
    required this.lastMessageTime,
    required this.lastMessage,
  });

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      chatId: map['chat_id'] as int? ?? 0,
      contactId: map['contact_id'] as int? ?? 0,
      userIds: (map['user_ids'] as List<dynamic>?)?.cast<int>() ?? [],
      chatTitle: map['chat_title'] as String? ?? '',
      lastMessageTime: DateTime.tryParse(map['last_message_time']?.toString() ?? '') ?? DateTime.now(),
      lastMessage: map['last_message'] as String? ?? '',
    );
  }
}