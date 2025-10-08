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

  // 💡 NEW FIELDS: Deletion Status (फील्ड 9-12 के बाद 13 और 14 का उपयोग करें)
  @HiveField(13)
  int isDeletedSender; // 0=false, 1=true

  @HiveField(14)
  int isDeletedReceiver; // 0=false, 1=true

  // ✅ NEW: Thumbnail for media preview (फील्ड 15 का उपयोग करें)
  @HiveField(15)
  Uint8List? thumbnail;

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
    this.thumbnail, // ✅ NEW: Thumbnail field added
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

    // Deletion fields को मैप से सुरक्षित रूप से पढ़ें (अगर वे API से आ रहे हैं, वरना 0)
    final int isDeletedSender = map['is_deleted_sender'] as int? ?? 0;
    final int isDeletedReceiver = map['is_deleted_receiver'] as int? ?? 0;

    // ✅ NEW: Thumbnail parsing (अगर server से base64 format में आता है)
    Uint8List? parsedThumbnail;
    if (map['thumbnail'] != null && map['thumbnail'] is String) {
      try {
        parsedThumbnail = base64.decode(map['thumbnail'] as String);
      } catch (e) {
        print('❌ Thumbnail decoding error: $e');
      }
    }

    // Time parsing logic...
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
      thumbnail: parsedThumbnail, // ✅ NEW: Thumbnail included
    );
  }

  // ✅ OPTIONAL: Helper method to check if message has thumbnail
  bool get hasThumbnail => thumbnail != null && thumbnail!.isNotEmpty;

  // ✅ OPTIONAL: Helper method to get display content for media messages
  String get displayContent {
    if (messageType == 'media' || messageType == 'encrypted_media') {
      return hasThumbnail ? '📷 Image' : '📷 Media';
    }
    return messageContent;
  }
}