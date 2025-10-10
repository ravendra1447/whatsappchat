import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:path/path.dart' as path;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

import '../config.dart';
import '../main.dart';
import '../models/chat_model.dart';
import 'crypto_manager.dart';
import '../utils/sound_utils.dart';

class ChatService {
  static late Box<Chat> _chatBox;
  static Box get _authBox => Hive.box('authBox');
  static Box<Message> get _messageBox => Hive.box<Message>('messages');

  static const String apiBase = "http://184.168.126.71/api";
  static const String socketBase = "http://184.168.126.71:3000";
  static final Dio _dio = Dio();

  static IO.Socket? _socket;
  static bool _isInitialized = false;
  static Timer? _pingTimer;
  static Timer? _statusUpdateTimer;

  static final StreamController<Map<String, dynamic>> _typingStatusController =
  StreamController.broadcast();
  static Stream<Map<String, dynamic>> get onTypingStatus =>
      _typingStatusController.stream;

  static final StreamController<Message> _newMessageController =
  StreamController<Message>.broadcast();
  static Stream<Message> get onNewMessage => _newMessageController.stream;

  static final StreamController<Map<String, dynamic>> _userStatusController =
  StreamController.broadcast();
  static Stream<Map<String, dynamic>> get onUserStatus =>
      _userStatusController.stream;

  static final StreamController<String> _messageDeliveredController =
  StreamController<String>.broadcast();
  static Stream<String> get onMessageDelivered => _messageDeliveredController.stream;

  static final StreamController<String> _messageSentController =
  StreamController<String>.broadcast();
  static Stream<String> get onMessageSent => _messageSentController.stream;

  static final StreamController<Map<String, dynamic>> _uploadProgressController =
  StreamController.broadcast();
  static Stream<Map<String, dynamic>> get onUploadProgress =>
      _uploadProgressController.stream;

  static final _cryptoManager = CryptoManager();
  static final Set<String> _processedMessageIds = {};
  static final Set<String> _uploadingMediaIds = {};

  // ✅ ADD: Track connected state to prevent multiple connections
  static bool _isConnecting = false;
  static DateTime? _lastSocketInitTime;

  static Future<void> init() async {
    _chatBox = Hive.box<Chat>('chatList');
    await _cryptoManager.init();
    _isInitialized = true;
    print("✅ Initialized ChatService");

    // ✅ DELAYED socket initialization to prevent race conditions
    Future.delayed(const Duration(milliseconds: 500), () {
      initSocket();
    });
  }

  static void initSocket() {
    // ✅ STRONG CHECK: Prevent multiple socket initializations
    if (_isConnecting) {
      print("⚠️ Socket connection already in progress, skipping...");
      return;
    }

    // ✅ PREVENT RAPID RE-INITIALIZATION (min 5 seconds between attempts)
    if (_lastSocketInitTime != null &&
        DateTime.now().difference(_lastSocketInitTime!).inSeconds < 5) {
      print("⚠️ Too soon for socket re-initialization, skipping...");
      return;
    }

    if (_socket != null && _socket!.connected) {
      print("✅ Socket already connected, skipping re-initialization");
      return;
    }

    final userId = _authBox.get('userId');
    if (userId == null) {
      print("❌ User ID not found in authBox");
      return;
    }

    _isConnecting = true;
    _lastSocketInitTime = DateTime.now();

    try {
      print("🔄 Creating fresh socket connection...");

      // ✅ CLEAN UP OLD SOCKET COMPLETELY
      if (_socket != null) {
        _cleanupSocketListeners();
        _socket!.disconnect();
        _socket!.destroy();
        _socket = null;
      }

      _socket = IO.io(
        socketBase,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(3) // ✅ REDUCE from 9999 to prevent spam
            .setReconnectionDelay(3000) // ✅ INCREASE delay
            .setTimeout(10000) // ✅ INCREASE timeout
            .build(),
      );

      // ✅ SETUP CONNECTION LISTENERS FIRST
      _socket!.onConnect((_) {
        _isConnecting = false;
        print("✅ Fresh socket connection established");
        _socket!.emit("register", userId);
        print("👤 Emitted 'register' for user $userId");

        // ✅ SETUP HEARTBEAT
        _setupHeartbeat();

        // ✅ JOIN CHAT ROOMS
        _joinChatRooms();

        // ✅ SETUP MESSAGE LISTENERS AFTER CONNECTION
        _setupMessageListeners();

        print("✅ Socket setup completed successfully");
      });

      _socket!.onDisconnect((reason) {
        _isConnecting = false;
        print("❌ Socket disconnected: $reason");
        _cleanupTimers();
      });

      _socket!.onConnectError((err) {
        _isConnecting = false;
        print("❌ Socket connect error: $err");
        _cleanupTimers();
      });

      _socket!.onError((err) {
        print("❌ Socket general error: $err");
      });

      // ✅ CONNECT SOCKET
      _socket!.connect();

    } catch (e) {
      _isConnecting = false;
      print("❌ Socket init error: $e");
      _cleanupTimers();
    }
  }

  // ✅ SEPARATE FUNCTION TO CLEANUP OLD LISTENERS
  static void _cleanupSocketListeners() {
    if (_socket != null) {
      _socket!.off("connect");
      _socket!.off("disconnect");
      _socket!.off("connect_error");
      _socket!.off("error");
      _socket!.off("ping");
      _socket!.off("new_message");
      _socket!.off("receive_message");
      _socket!.off("message_delivered");
      _socket!.off("mark_delivered_bulk");
      _socket!.off("message_read");
      _socket!.off("user_typing");
      _socket!.off("user_status");
      _socket!.off("media_upload_progress");
      _socket!.off("media_message_ready");
    }
    print("✅ Cleaned up old socket listeners");
  }

  // ✅ SEPARATE FUNCTION FOR HEARTBEAT
  static void _setupHeartbeat() {
    // Clean up old timers
    _pingTimer?.cancel();
    _statusUpdateTimer?.cancel();

    // Setup ping-pong heartbeat
    _socket!.on("ping", (_) {
      print("❤️ Received 'ping', sending 'pong'");
      _socket!.emit("pong");
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit("pong");
        print("❤️ Proactively sending 'pong' heartbeat");
      } else {
        _pingTimer?.cancel();
      }
    });

    // Setup status update heartbeat
    final userId = _authBox.get('userId');
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_socket != null && _socket!.connected && userId != null) {
        _socket!.emit("user_status", {"userId": userId, "status": "online"});
        print("🌐 Sending online status heartbeat");
      } else {
        _statusUpdateTimer?.cancel();
      }
    });
  }

  // ✅ SEPARATE FUNCTION FOR JOINING CHAT ROOMS
  static void _joinChatRooms() {
    final chatIds = _messageBox.values.map((m) => m.chatId).toSet();
    for (final id in chatIds) {
      _socket!.emit("join_chat", id);
      print("✅ Joined chat room: $id");
    }
    print("✅ Joined ${chatIds.length} chat rooms");
  }

  // ✅ SEPARATE FUNCTION FOR MESSAGE LISTENERS
  static void _setupMessageListeners() {
    // ✅ NEW MESSAGE LISTENER with STRONG duplicate protection
    _socket!.on("new_message", (data) async {
      print("📨 [new_message] event received");
      try {
        final messageId = data["message_id"]?.toString();
        final tempId = data["temp_id"]?.toString();
        final idToProcess = messageId ?? tempId;

        if (idToProcess == null) {
          print("❌ [new_message] No valid message ID");
          return;
        }

        // ✅ STRONG DUPLICATE CHECK
        if (_processedMessageIds.contains(idToProcess)) {
          print("⚠️ [new_message] Duplicate blocked: $idToProcess");
          return;
        }

        await _handleIncomingData(data, source: "new_message");
        SoundUtils.playReceiveSound();
      } catch (e) {
        print("❌ [new_message] Error: $e");
      }
    });

    // ✅ RECEIVE MESSAGE LISTENER with STRONG duplicate protection
    _socket!.on("receive_message", (data) async {
      print("📨 [receive_message] event received");
      try {
        final messageId = data["message_id"]?.toString();
        final tempId = data["temp_id"]?.toString();
        final idToProcess = messageId ?? tempId;

        if (idToProcess == null) {
          print("❌ [receive_message] No valid message ID");
          return;
        }

        // ✅ STRONG DUPLICATE CHECK
        if (_processedMessageIds.contains(idToProcess)) {
          print("⚠️ [receive_message] Duplicate blocked: $idToProcess");
          return;
        }

        await _handleIncomingData(data, source: "receive_message", forceDelivered: true);
      } catch (e) {
        print("❌ [receive_message] Error: $e");
      }
    });

    // ✅ MEDIA MESSAGE READY LISTENER with STRONG duplicate protection
    _socket!.on("media_message_ready", (data) async {
      print("📨 [media_message_ready] event received");
      try {
        final messageId = data["message_id"]?.toString();
        final tempId = data["temp_id"]?.toString();
        final idToProcess = messageId ?? tempId;

        if (idToProcess == null) {
          print("❌ [media_message_ready] No valid message ID");
          return;
        }

        // ✅ STRONG DUPLICATE CHECK
        if (_processedMessageIds.contains(idToProcess)) {
          print("⚠️ [media_message_ready] Duplicate blocked: $idToProcess");
          return;
        }

        await _handleIncomingData(data, source: "media_message_ready", forceDelivered: true);
      } catch (e) {
        print("❌ [media_message_ready] Error: $e");
      }
    });

    // ✅ MESSAGE DELIVERED LISTENER
    _socket!.on("message_delivered", (data) async {
      final messageId = data["message_id"]?.toString();
      if (messageId != null) {
        await updateDeliveryStatus(messageId, 1);
        print("✅ [message_delivered] Delivery confirmed: $messageId");
        SoundUtils.playDeliveredSound();
      }
    });

    // ✅ BULK MESSAGE DELIVERED LISTENER
    _socket!.on("mark_delivered_bulk", (data) async {
      final ids = data["message_ids"] as List<dynamic>? ?? [];
      int updatedCount = 0;

      for (var id in ids) {
        final msg = _messageBox.get(id.toString()) as Message?;
        if (msg != null && msg.isDelivered == 0) {
          msg.isDelivered = 1;
          await _messageBox.put(msg.messageId, msg);
          _newMessageController.add(msg);
          updatedCount++;
        }
      }
      print("✅ [mark_delivered_bulk] Updated $updatedCount messages");
    });

    // ✅ MESSAGE READ LISTENER
    _socket!.on("message_read", (data) async {
      try {
        List<dynamic> messageIds = [];
        if (data["message_ids"] != null) {
          messageIds = data["message_ids"];
        } else if (data["message_id"] != null) {
          messageIds = [data["message_id"]];
        }

        if (messageIds.isEmpty) return;

        int readCount = 0;
        for (var id in messageIds) {
          final messageId = id.toString();
          await markMessageReadLocal(messageId);
          readCount++;
        }

        print("✅ [message_read] Marked $readCount messages as read");
        SoundUtils.playReadSound();
      } catch (e) {
        print("❌ [message_read] Error: $e");
      }
    });

    // ✅ USER TYPING LISTENER
    _socket!.on("user_typing", (data) {
      print("✍️ [user_typing] event received");
      _typingStatusController.sink.add({
        "chatId": data["chat_id"],
        "userId": data["user_id"],
        "isTyping": data["isTyping"] ?? false
      });
    });

    // ✅ USER STATUS LISTENER
    _socket!.on("user_status", (data) {
      print("🌐 [user_status] event received");
      _userStatusController.sink.add({
        "userId": data["userId"]?.toString(),
        "status": data["status"]?.toString() ?? "offline"
      });
    });

    // ✅ MEDIA UPLOAD PROGRESS LISTENER
    _socket!.on("media_upload_progress", (data) {
      final tempId = data["temp_id"]?.toString();
      final progress = data["progress"]?.toDouble();
      if (tempId != null && progress != null) {
        _uploadProgressController.sink.add({
          "tempId": tempId,
          "progress": progress,
        });
      }
    });

    print("✅ All socket listeners setup completed");
  }

  // ✅ CLEANUP TIMERS FUNCTION
  static void _cleanupTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
    print("✅ Cleaned up socket timers");
  }

  static bool get isConnected => _socket?.connected ?? false;

  static void disposeSocket() {
    final userId = _authBox.get('userId');
    if (_socket != null && _socket!.connected && userId != null) {
      _socket!.emit("user_status", {
        "userId": userId,
        "status": "offline"
      });
    }

    _cleanupTimers();
    _cleanupSocketListeners();

    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    _isInitialized = false;
    _isConnecting = false;

    // ✅ CLEAR PROCESSED MESSAGE IDs
    _processedMessageIds.clear();
    _uploadingMediaIds.clear();

    print("🔌 Socket completely disposed");
  }

  // ------------------- HANDLE INCOMING DATA - COMPLETELY FIXED -------------------
  static Future<void> _handleIncomingData(dynamic data,
      {String source = "", bool forceDelivered = false}) async {
    String? idToProcess;

    try {
      final currentUserId = _authBox.get('userId');
      if (currentUserId == null) {
        print("❌ User ID not found in authBox");
        return;
      }

      final messageId = data["message_id"]?.toString();
      final tempId = data["temp_id"]?.toString();
      idToProcess = messageId ?? tempId;

      if (idToProcess == null) {
        print("❌ Incoming data has no valid message_id or temp_id. Ignoring.");
        return;
      }

      print("📥 Processing message from $source: $idToProcess");

      // ✅ STRONG DUPLICATE PROTECTION - Multiple layers
      if (_processedMessageIds.contains(idToProcess)) {
        print("⚠️ Message already being processed: $idToProcess");
        return;
      }
      _processedMessageIds.add(idToProcess);

      // Auto-clean after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        _processedMessageIds.remove(idToProcess!);
      });

      // ✅ STEP 1: Handle tempId to messageId conversion FIRST
      if (tempId != null && messageId != null) {
        await updateMessageId(tempId, messageId, forceDelivered ? 1 : 0);
        print("✅ TempId converted: $tempId -> $messageId");

        // After conversion, check if message already exists with new ID
        final existingWithNewId = _messageBox.values.firstWhereOrNull(
              (msg) => msg.messageId == messageId,
        );

        if (existingWithNewId != null) {
          print("⚠️ Message already exists with new ID: $messageId");
          return;
        }
      }

      // ✅ STEP 2: STRONG DUPLICATE CHECK - Check by ID
      final existingById = _messageBox.values.firstWhereOrNull(
            (msg) => msg.messageId == idToProcess,
      );

      if (existingById != null) {
        print("⚠️ Message already exists in database: $idToProcess");
        return;
      }

      // ✅ STEP 3: Process message content
      final messageContent = data["message_text"]?.toString() ?? "";
      final mediaUrl = data["media_url"]?.toString() ?? "";
      final messageType = data["message_type"]?.toString() ?? "text";
      final messageTimestamp = DateTime.tryParse(data["timestamp"]?.toString() ?? "") ?? DateTime.now();
      final chatId = int.tryParse(data["chat_id"]?.toString() ?? "0") ?? 0;
      final senderId = int.tryParse(data["sender_id"]?.toString() ?? "0") ?? 0;

      String finalContent = messageContent;
      String finalMessageType = messageType;

      print("🔄 Processing content:");
      print("   Type: $messageType");
      print("   Media URL: $mediaUrl");
      print("   Temp ID: $tempId");
      print("   Message ID: $messageId");

      // ✅ STEP 4: Handle different message types
      if (messageType == "encrypted") {
        try {
          // ✅ FIRST: Check if this is actually a media message disguised as encrypted
          if (mediaUrl.isNotEmpty && messageContent == "media") {
            print("🔄 Detected media message in encrypted format");
            final fileName = mediaUrl.split('/').last;
            finalContent = '${Config.baseNodeApiUrl}/media/file/$fileName';
            finalMessageType = "media";
            print("✅ Converted to media message: $finalContent");
          } else {
            // Try actual decryption for text messages
            final decryptedData = await _cryptoManager.decryptAndDecompress(messageContent);
            final decodedData = jsonDecode(decryptedData['content']);
            finalContent = decodedData['content'] ?? "[Decryption Failed]";
            finalMessageType = decodedData['type'] ?? "text";
            print("✅ Decrypted text message: $finalContent");
          }
        } catch (e) {
          print("❌ Decryption failed: $e");
          // ✅ FALLBACK: If decryption fails but we have media URL, treat as media
          if (mediaUrl.isNotEmpty) {
            final fileName = mediaUrl.split('/').last;
            finalContent = '${Config.baseNodeApiUrl}/media/file/$fileName';
            finalMessageType = "media";
            print("🔄 Fallback to media message: $finalContent");
          } else {
            finalContent = "[Decryption Failed]";
            finalMessageType = "text";
          }
        }
      } else if (messageType == "media") {
        // ✅ Media message - server sends media_url directly
        if (mediaUrl.isNotEmpty) {
          final fileName = mediaUrl.split('/').last;

          // ✅ IMPORTANT: Check if it's already a full URL
          if (mediaUrl.startsWith('http')) {
            finalContent = mediaUrl;
          } else {
            finalContent = '${Config.baseNodeApiUrl}/media/file/$fileName';
          }

          finalMessageType = "media";
          print("✅ Media message processed: $finalContent");

          // Test the media URL
          await _testMediaUrl(finalContent);
        } else {
          finalContent = "[Media URL Missing]";
          finalMessageType = "text";
          print("❌ Media message but no media_url found in data");
        }
      } else if (messageType == "text") {
        // Plain text message
        finalContent = messageContent;
        finalMessageType = "text";
        print("✅ Plain text message received: $finalContent");
      } else {
        // Handle unknown message types gracefully
        print("⚠️ Unknown message type: $messageType, treating as text");
        finalContent = messageContent.isNotEmpty ? messageContent : "[Message]";
        finalMessageType = "text";
      }

      // ✅ STEP 5: FINAL DUPLICATE CHECK - Check if we already have this exact message
      final finalExistingCheck = _messageBox.values.firstWhereOrNull(
            (msg) =>
        msg.chatId == chatId &&
            msg.senderId == senderId &&
            msg.messageContent == finalContent &&
            msg.timestamp.difference(messageTimestamp).inSeconds.abs() < 3,
      );

      if (finalExistingCheck != null) {
        print("⚠️ FINAL DUPLICATE CHECK FAILED - Message already exists: $idToProcess");
        print("   Existing ID: ${finalExistingCheck.messageId}");
        return;
      }

      // ✅ STEP 6: Create and save message
      final msg = Message(
        messageId: idToProcess,
        chatId: chatId,
        senderId: senderId,
        receiverId: int.tryParse(data["receiver_id"]?.toString() ?? "0") ?? 0,
        messageContent: finalContent,
        messageType: finalMessageType,
        isRead: 0,
        isDelivered: forceDelivered ? 1 : 0,
        timestamp: messageTimestamp,
        senderName: data["sender_name"]?.toString(),
        receiverName: data["receiver_name"]?.toString(),
        senderPhoneNumber: data["sender_phone"]?.toString(),
        receiverPhoneNumber: data["receiver_phone"]?.toString(),
      );

      await saveMessageLocal(msg);
      print("💾 Message saved successfully: $idToProcess");

      // ✅ STEP 7: Notify UI
      _newMessageController.add(msg);

      // ✅ STEP 8: Send delivery confirmation if this message is for current user
      final isForCurrentUser = currentUserId.toString() != data["sender_id"].toString();
      if (isForCurrentUser && _socket != null && _socket!.connected) {
        _socket!.emit("message_delivered", {
          "message_id": idToProcess,
          "chat_id": msg.chatId,
          "receiver_id": currentUserId,
        });

        await updateDeliveryStatus(idToProcess, 1);
        print("📤 Delivery confirmed: $idToProcess");
      }

      print("✅ Message processing completed successfully: $idToProcess");

    } catch (e, st) {
      print("❌ Error in _handleIncomingData: $e");
      print("Stack: $st");
    } finally {
      // ✅ ALWAYS remove from processed IDs
      if (idToProcess != null) {
        _processedMessageIds.remove(idToProcess);
      }
    }
  }

  // ------------------- MEDIA URL TEST FUNCTION -------------------
  static Future<void> _testMediaUrl(String mediaUrl) async {
    try {
      print("🔍 Testing media URL: $mediaUrl");
      final response = await http.head(Uri.parse(mediaUrl));
      print("🔍 Media URL test result: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("✅ Media URL is accessible and working!");
      } else {
        print("❌ Media URL returned status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Media URL test failed: $e");
    }
  }

  // ------------------- UPDATE / DELIVERY FUNCTIONS -------------------
  static Future<void> updateMessageId(String tempId, String newMessageId, int status) async {
    try {
      final msg = _messageBox.get(tempId) as Message?;
      if (msg != null) {
        // ✅ FIRST: Check if new message ID already exists
        final existingWithNewId = _messageBox.values.firstWhereOrNull(
              (m) => m.messageId == newMessageId,
        );

        if (existingWithNewId != null) {
          print("⚠️ Message with new ID already exists: $newMessageId");
          // Delete the temporary message to avoid duplicates
          await _messageBox.delete(tempId);
          return;
        }

        // ✅ Update message ID and status
        msg.messageId = newMessageId;
        msg.isDelivered = status;

        await _messageBox.delete(tempId);
        await _messageBox.put(newMessageId, msg);

        print("✅ TempId $tempId replaced with $newMessageId (status=$status)");

        _newMessageController.add(msg);
      } else {
        print("⚠️ No message found with tempId=$tempId");
      }
    } catch (e) {
      print("❌ Error updating MessageId: $e");
    }
  }

  static Future<void> updateDeliveryStatus(String messageId, int status) async {
    try {
      final msg = _messageBox.get(messageId) as Message?;
      if (msg != null) {
        msg.isDelivered = status;
        await _messageBox.put(messageId, msg);
        print("✅ Delivery status updated for $messageId = $status");

        _newMessageController.add(msg);
        _messageDeliveredController.sink.add(messageId);
      } else {
        print("⚠️ No message found with ID $messageId");
      }
    } catch (e) {
      print("❌ Error updating delivery status: $e");
    }
  }

  /// Mark all messages of a user as delivered (double tick)
  static Future<void> markAllMessagesAsDelivered(int userId) async {
    try {
      final messages = _messageBox.values
          .where((m) => m.receiverId == userId && m.isDelivered == 0)
          .toList();

      final messageIds = <int>[];
      for (final msg in messages) {
        msg.isDelivered = 1;
        await _messageBox.put(msg.messageId, msg);
        _newMessageController.add(msg);

        messageIds.add(msg.messageId as int);
      }

      if (messageIds.isNotEmpty && ChatService._socket != null && ChatService._socket!.connected) {
        ChatService._socket!.emit("mark_delivered_bulk", {
          "message_ids": messageIds,
          "receiver_id": userId,
        });
      }

      print("✅ All messages marked delivered locally and server notified for userId=$userId");
    } catch (e) {
      print("❌ Error marking messages delivered: $e");
    }
  }

  // ------------------- SAVE / READ -------------------
  static Future<void> saveMessageLocal(Message message) async {
    try {
      // ✅ FINAL SAFETY CHECK before saving
      final existingMessage = _messageBox.values.firstWhereOrNull(
            (msg) =>
        msg.messageId == message.messageId ||
            (msg.chatId == message.chatId &&
                msg.senderId == message.senderId &&
                msg.messageContent == message.messageContent &&
                msg.timestamp.difference(message.timestamp).inSeconds.abs() < 3),
      );

      if (existingMessage != null) {
        print("⚠️ DUPLICATE BLOCKED in saveMessageLocal: ${message.messageId}");
        print("   Existing ID: ${existingMessage.messageId}");
        return;
      }

      await _messageBox.put(message.messageId, message);
      print("💾 Message saved to local storage: ${message.messageId}");
    } catch (e) {
      print("❌ Error saving message locally: $e");
    }
  }

  static Future<void> markMessageReadLocal(String messageId) async {
    try {
      final msg = (_messageBox.get(messageId) as Message?);
      if (msg != null) {
        msg.isRead = 1;
        await _messageBox.put(messageId, msg);
        print("💾 Local Hive updated as read: $messageId");

        _newMessageController.add(msg);
      } else {
        print("⚠️ No message found in Hive with ID $messageId");
      }
    } catch (e) {
      print("❌ Error marking message read locally: $e");
    }
  }

  static void joinRoom(int chatId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit("join_chat", chatId);
      print("✅ Joined room: $chatId");
    } else {
      print("⚠️ Socket not connected, trying to reconnect...");
      initSocket();
      Future.delayed(const Duration(seconds: 2), () {
        if (_socket != null && _socket!.connected) {
          _socket!.emit("join_chat", chatId);
        }
      });
    }
  }

  static void leaveRoom(int chatId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit("leave_room", {"chat_id": chatId});
      print("🚪 Left room: $chatId");
    }
  }

  static void startTyping(int chatId) {
    final userId = _authBox.get('userId');
    if (_socket != null && _socket!.connected && userId != null) {
      _socket!.emit("typing_start", {"chat_id": chatId, "user_id": userId});
    }
  }

  static void stopTyping(int chatId) {
    final userId = _authBox.get('userId');
    if (_socket != null && _socket!.connected && userId != null) {
      _socket!.emit("typing_stop", {"chat_id": chatId, "user_id": userId});
    }
  }

  static List<Message> getLocalMessages(int chatId) {
    try {
      return _messageBox.values
          .where((m) => m.chatId == chatId)
          .where((m) => !m.messageId.toString().startsWith('temp_'))
          .cast<Message>()
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      print("❌ Error getting local messages: $e");
      return [];
    }
  }

  static Future<int?> createChat(int otherUserId) async {
    try {
      final userId = _authBox.get('userId');
      if (userId == null) return null;

      final res = await http.post(
        Uri.parse("$apiBase/create_chat.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sender_id": userId.toString(),
          "receiver_id": otherUserId.toString(),
        }),
      );

      if (res.statusCode != 200) {
        print("❌ HTTP Error: ${res.statusCode}");
        return null;
      }

      final data = jsonDecode(res.body);
      if (data["success"] == true && data.containsKey("chat_id")) {
        final chatId = int.tryParse(data["chat_id"].toString());
        if (chatId != null) {
          final chat = Chat(
            chatId: chatId,
            contactId: otherUserId,
            userIds: [],
            chatTitle: '',
          );
          await _chatBox.put(chatId, chat);
          print("💾 Saved new chat in Hive for chatId=$chatId");
        }
        return chatId;
      }
      return null;
    } catch (e) {
      print("❌ Create chat error: $e");
      return null;
    }
  }

  static Future<void> fetchMessages(int chatId) async {
    try {
      final res =
      await http.get(Uri.parse("$apiBase/get_messages.php?chat_id=$chatId"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true && data["messages"] != null) {
          for (var msg in data["messages"]) {
            await _handleIncomingData(msg);
          }
          print("✅ Messages loaded for chatId=$chatId: ${data["messages"].length}");
        }
      } else {
        print("❌ HTTP Error: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ Fetch messages error: $e");
    }
  }

  /// Fetch all messages for home screen
  static Future<void> fetchAllChatsAndMessages() async {
    if (!_isInitialized) return;

    final chatIds = _messageBox.values.map((m) => m.chatId).toSet();
    for (final chatId in chatIds) {
      await fetchMessages(chatId);
    }
    print("✅ Fetched all messages for home screen");
  }

  // ==================== CORRECTED MEDIA UPLOAD ====================

  /// Send media message using server's 3-step upload process
  static Future<void> sendMediaMessage({
    required int chatId,
    required int receiverId,
    required String mediaPath,
    String? senderName,
    String? receiverName,
    String? senderPhoneNumber,
    String? receiverPhoneNumber,
  }) async {
    final tempId = 'temp_${chatId}_${DateTime.now().microsecondsSinceEpoch}';
    if (!_isInitialized) {
      throw Exception("ChatService has not been initialized. Cannot send media message.");
    }

    if (_socket == null || !_socket!.connected) {
      print("❌ Socket not connected. Attempting to reconnect...");
      initSocket();
      await Future.delayed(const Duration(seconds: 2));
      if (_socket == null || !_socket!.connected) {
        throw Exception("Socket not connected. Cannot send media message.");
      }
    }

    final userId = _authBox.get('userId');
    if (userId == null) throw Exception("User ID not found");

    try {
      // ✅ STEP 1: Create immediate temporary message for instant UI update
      final tempMsg = Message(
        messageId: tempId,
        chatId: chatId,
        senderId: userId,
        receiverId: receiverId,
        messageContent: mediaPath,
        messageType: 'media',
        isRead: 0,
        isDelivered: 0,
        timestamp: DateTime.now(),
        senderName: senderName,
        receiverName: receiverName,
        senderPhoneNumber: senderPhoneNumber,
        receiverPhoneNumber: receiverPhoneNumber,
      );

      await saveMessageLocal(tempMsg);
      print("💾 Saved temporary media message with instant preview: $tempId");

      // ✅ Notify UI immediately
      _newMessageController.add(tempMsg);
      _messageSentController.sink.add(tempId);
      SoundUtils.playSendSound();

      // ✅ STEP 2: Process and upload media in background
      _processAndSendMedia(
        mediaPath: mediaPath,
        chatId: chatId,
        receiverId: receiverId,
        tempId: tempId,
        userId: userId,
        senderName: senderName,
        receiverName: receiverName,
        senderPhoneNumber: senderPhoneNumber,
        receiverPhoneNumber: receiverPhoneNumber,
      );

    } catch (e) {
      print("❌ Initial media message setup error: $e");
      rethrow;
    }
  }

  /// Background processing and uploading of media
  static Future<void> _processAndSendMedia({
    required String mediaPath,
    required int chatId,
    required int receiverId,
    required String tempId,
    required int userId,
    String? senderName,
    String? receiverName,
    String? senderPhoneNumber,
    String? receiverPhoneNumber,
  }) async {
    if (_uploadingMediaIds.contains(tempId)) {
      print("⚠️ Media $tempId is already being uploaded");
      return;
    }

    _uploadingMediaIds.add(tempId);

    try {
      // ✅ STEP 1: Check if temp message exists
      final existingTempMsg = _messageBox.get(tempId) as Message?;
      if (existingTempMsg == null) {
        print("❌ Temporary message not found");
        return;
      }

      // ✅ STEP 2: Compress media
      Uint8List fileBytes;
      final ext = mediaPath.split('.').last.toLowerCase();

      if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          mediaPath,
          quality: 60,
          minWidth: 1200,
          minHeight: 1200,
        );
        fileBytes = Uint8List.fromList(compressedBytes ?? await File(mediaPath).readAsBytes());
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
        final MediaInfo? info = await VideoCompress.compressVideo(
          mediaPath,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info != null && info.file != null) {
          fileBytes = await File(info.file!.path).readAsBytes();
        } else {
          fileBytes = await File(mediaPath).readAsBytes();
        }
      } else {
        fileBytes = await File(mediaPath).readAsBytes();
      }

      final originalName = path.basename(mediaPath);
      final totalSize = fileBytes.length;

      print("📦 Prepared media for upload: $originalName ($totalSize bytes)");

      // ✅ STEP 3: Upload using server's 3-step process
      final String? mediaUrl = await _uploadMediaToServer(
          fileBytes,
          originalName,
          totalSize,
          tempId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          onProgress: (progress) {
            _uploadProgressController.sink.add({
              'tempId': tempId,
              'progress': progress,
            });
          }
      );

      if (mediaUrl == null) {
        throw Exception("Failed to upload media to server.");
      }

      print("✅ Media uploaded successfully: $mediaUrl");

      // ✅ STEP 4: Send final media message via socket
      final fileName = mediaUrl.split('/').last;
      final fullMediaUrl = '${Config.baseNodeApiUrl}/media/file/$fileName';

      // ✅ Prepare encrypted payload for media
      final Map<String, dynamic> mediaPayload = {
        'type': 'media',
        'content': fullMediaUrl,
      };

      final String payloadString = jsonEncode(mediaPayload);
      final encryptedData = await _cryptoManager.encryptAndCompress(payloadString);
      final encryptedContent = encryptedData['content'];
      final encryptedType = encryptedData['type'];

      // ✅ Send via socket
      if (_socket != null && _socket!.connected) {
        _socket!.emit("send_message", {
          "chat_id": chatId,
          "sender_id": userId,
          "receiver_id": receiverId,
          "message_text": encryptedContent,
          "message_type": encryptedType,
          "temp_id": tempId,
          "media_url": fullMediaUrl,
          "sender_name": senderName,
          "receiver_name": receiverName,
          "sender_phone": senderPhoneNumber,
          "receiver_phone": receiverPhoneNumber,
          "timestamp": DateTime.now().toIso8601String(),
        });
        print("📤 Emitted send_message for media with temp_id: $tempId");
      }

      // ✅ STEP 5: Update local temporary message
      existingTempMsg.messageContent = fullMediaUrl;
      existingTempMsg.isDelivered = 1;
      await _messageBox.put(tempId, existingTempMsg);
      _newMessageController.add(existingTempMsg);

      print("✅ Media message sent and local temp message updated: $fullMediaUrl");

      // ✅ STEP 6: Send push notification
      await _sendPushNotification(receiverId, '📷 Media', chatId, userId, senderName ?? 'User');

    } catch (e) {
      print("❌ Media upload error: $e");
      _uploadProgressController.sink.add({
        'tempId': tempId,
        'progress': -1.0,
      });
    } finally {
      _uploadingMediaIds.remove(tempId);
    }
  }

  /// ✅ CORRECTED: Upload using server's 3-step API
  static Future<String?> _uploadMediaToServer(
      Uint8List fileBytes,
      String fileName,
      int totalSize,
      String tempId, {
        required int chatId,
        required int senderId,
        required int receiverId,
        required Function(double) onProgress,
      }) async {
    try {
      const int chunkSize = 512 * 1024;
      final int totalChunks = (fileBytes.length / chunkSize).ceil();

      print("📤 Uploading $fileName in $totalChunks chunks...");

      // ✅ STEP 1: Initialize upload session
      final initResponse = await _dio.post(
        "${Config.baseNodeApiUrl}/media/init",
        data: {
          "chat_id": chatId,
          "sender_id": senderId,
          "original_name": fileName,
          "total_size": totalSize,
        },
      );

      if (initResponse.statusCode != 200 || initResponse.data['success'] != true) {
        throw Exception("Upload initialization failed: ${initResponse.data}");
      }

      final String uploadId = initResponse.data['upload_id'];
      print("✅ Upload session started: $uploadId");

      // ✅ STEP 2: Upload chunks
      int completedChunks = 0;
      for (int i = 0; i < totalChunks; i++) {
        final int start = i * chunkSize;
        final int end = min(start + chunkSize, fileBytes.length);
        final Uint8List chunkBytes = fileBytes.sublist(start, end);

        int attempt = 0;
        bool success = false;

        while (attempt < 3 && !success) {
          try {
            final FormData form = FormData.fromMap({
              "upload_id": uploadId,
              "chunk": MultipartFile.fromBytes(chunkBytes, filename: "$fileName.part$i"),
            });

            final response = await _dio.post(
                "${Config.baseNodeApiUrl}/media/chunk",
                data: form
            );

            if (response.statusCode != 200 || response.data['success'] != true) {
              throw Exception("Chunk upload failed: ${response.data}");
            }

            completedChunks++;
            final double progress = (completedChunks / totalChunks) * 100;
            onProgress(progress);

            print("📦 Chunk ${i + 1}/$totalChunks uploaded ($progress%)");
            success = true;
          } catch (e) {
            attempt++;
            if (attempt < 3) {
              print("⚠️ Retry chunk ${i + 1}, attempt $attempt");
              await Future.delayed(const Duration(seconds: 2));
            } else {
              throw Exception("❌ Chunk ${i + 1} failed after 3 attempts: $e");
            }
          }
        }
      }

      // ✅ STEP 3: Finalize upload
      final finalizeResponse = await _dio.post(
          "${Config.baseNodeApiUrl}/media/finalize",
          data: {
            "upload_id": uploadId,
            "receiver_id": receiverId,
            "temp_id": tempId,
          }
      );

      if (finalizeResponse.statusCode == 200 && finalizeResponse.data['success'] == true) {
        final String mediaUrl = finalizeResponse.data['data']['media_url'];
        print("✅ Upload finalized: $mediaUrl");
        onProgress(100);
        return mediaUrl;
      } else {
        throw Exception("Finalize upload failed: ${finalizeResponse.data}");
      }

    } catch (e) {
      print("❌ Upload failed for $fileName: $e");
      onProgress(-1.0);
      return null;
    }
  }

  /// Send push notification for media
  static Future<void> _sendPushNotification(int receiverId, String messageText, int chatId, int senderId, String senderName) async {
    try {
      const apiUrl = 'http://184.168.126.71:3000/api/send-notification';
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'receiverId': receiverId,
          'messageText': messageText,
          'chatId': chatId,
          'senderId': senderId,
          'senderName': senderName,
          'type': 'media'
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Media notification sent successfully!');
      } else {
        print('❌ Failed to send media notification: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending media notification: $e');
    }
  }

  // ------------------- SEND MESSAGE FUNCTIONS -------------------
  static Future<void> sendMessage({
    required int chatId,
    required int receiverId,
    required String messageContent,
    required String messageType,
    String? senderName,
    String? receiverName,
    String? senderPhoneNumber,
    String? receiverPhoneNumber,
    bool isForwarded = false,
  }) async {
    if (!_isInitialized) {
      throw Exception("ChatService has not been initialized. Cannot send message.");
    }

    if (_socket == null || !_socket!.connected) {
      print("❌ Socket not connected. Attempting to reconnect...");
      initSocket();
      await Future.delayed(const Duration(seconds: 2));
      if (_socket == null || !_socket!.connected) {
        throw Exception("Socket not connected. Cannot send message.");
      }
    }

    try {
      final userId = _authBox.get('userId');
      if (userId == null) return;

      final Map<String, dynamic> messagePayload = {
        'type': messageType,
        'content': messageContent,
      };

      if (isForwarded) {
        messagePayload['is_forwarded'] = true;
      }

      final String payloadString = jsonEncode(messagePayload);
      final encryptedData = await _cryptoManager.encryptAndCompress(payloadString);
      final encryptedContent = encryptedData['content'];
      final encryptedType = encryptedData['type'];

      final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

      final tempMsg = Message(
        messageId: tempId,
        chatId: chatId,
        senderId: userId,
        receiverId: receiverId,
        messageContent: messageContent,
        messageType: messageType,
        isRead: 0,
        timestamp: DateTime.now(),
        isDelivered: 0,
        senderName: senderName,
        receiverName: receiverName,
        senderPhoneNumber: senderPhoneNumber,
        receiverPhoneNumber: receiverPhoneNumber,
      );

      await saveMessageLocal(tempMsg);
      print("💾 Saved temporary message locally with ID: $tempId");

      _socket!.emit("send_message", {
        "chat_id": chatId,
        "sender_id": userId,
        "receiver_id": receiverId,
        "message_text": encryptedContent,
        "message_type": encryptedType,
        "temp_id": tempId,
        "sender_name": senderName,
        "receiver_name": receiverName,
        "sender_phone": senderPhoneNumber,
        "receiver_phone": receiverPhoneNumber,
      });

      print("✅ Emitted 'send_message' to socket server");
      SoundUtils.playSendSound();

      // ✅ Send push notification to the receiver
      try {
        const apiUrl = 'http://184.168.126.71:3000/api/send-notification';
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'receiverId': receiverId,
            'messageText': messageContent,
            'chatId': chatId,
            'senderId': userId,
            'senderName': senderName ?? 'User',
          }),
        );

        if (response.statusCode == 200) {
          print('✅ Notification sent successfully!');
        } else {
          print('❌ Failed to send notification: ${response.body}');
        }
      } catch (e) {
        print('❌ Error sending notification: $e');
      }

    } catch (e) {
      print("❌ sendMessage error: $e");
      rethrow;
    }
  }

  // ------------------- FORWARD MESSAGE FUNCTIONS -------------------
  static Future<void> forwardMessages({
    required Set<int> originalMessageIds,
    required int targetChatId,
  }) async {
    if (!_isInitialized) {
      throw Exception("ChatService has not been initialized.");
    }

    final List<Message> messagesToForward = originalMessageIds
        .map((id) => _messageBox.get(id.toString()))
        .whereType<Message>()
        .toList();

    print("DEBUG: Forwarding ${messagesToForward.length} messages to chatId=$targetChatId");

    for (final msg in messagesToForward) {
      await _forwardMessage(
        originalMessage: msg,
        targetChatId: targetChatId,
      );
    }
  }

  static Future<void> _forwardMessage({
    required Message originalMessage,
    required int targetChatId,
  }) async {
    final myUserId = _authBox.get('userId');
    if (myUserId == null) return;

    final chat = _chatBox.get(targetChatId) as Chat?;
    final receiverId = chat?.contactId;

    if (receiverId == null) {
      print("⚠️ Forward failed: receiverId is null for chatId=$targetChatId");
      return;
    }

    print(
        "➡️ Forwarding messageId=${originalMessage.messageId} from userId=$myUserId to receiverId=$receiverId for chatId=$targetChatId");

    _socket?.emit("forward_messages", {
      "original_message_id": originalMessage.messageId,
      "forwarded_by_id": myUserId,
      "to_chat_id": targetChatId,
      "to_user_id": receiverId,
    });
  }

  /// Ensure socket is connected and user online
  static Future<void> ensureConnected() async {
    final userId = _authBox.get('userId');
    if (userId == null) return;

    if (_socket == null || !_socket!.connected) {
      print("⚠️ Socket disconnected. Reconnecting...");
      initSocket();
      // Wait for connection
      await Future.delayed(const Duration(seconds: 2));
    }

    // Ensure user status is online
    if (_socket != null && _socket!.connected) {
      _socket!.emit("user_status", {"userId": userId, "status": "online"});
      print("🌐 Ensured online status");
    }
  }

  static Future<void> markMessageRead(String messageId, int chatId) async {
    try {
      final userId = _authBox.get('userId');
      if (userId == null) return;

      await markMessageReadLocal(messageId);

      final res = await http.post(
        Uri.parse("$apiBase/mark_read.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message_id": messageId}),
      );
      if (res.statusCode == 200) {
        print("✅ Marked as read on server via API: $messageId");
      } else {
        print("❌ API error marking read: ${res.statusCode}");
      }

      if (_socket != null && _socket!.connected) {
        _socket!.emit("mark_read_bulk", {
          "message_ids": [messageId],
          "chat_id": chatId,
          "reader_id": userId,
        });
        print("📤 Sent 'mark_read_bulk' event to socket for $messageId");
      }

    } catch (e) {
      print("❌ Mark read error: $e");
    }
  }

  // ------------------- DELETE MESSAGE FUNCTION -------------------
  static Future<void> deleteMessage({
    required String messageId,
    required int userId,
    required String role, // 'sender' or 'receiver'
  }) async {
    try {
      const apiUrl = "${Config.baseNodeApiUrl}/delete_message";

      final res = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "messageId": messageId,
          "userId": userId,
          "role": role,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true) {
          print("✅ Message deletion processed successfully on server: $messageId");

          await _updateMessageDeletionStatusLocal(messageId, role);

        } else {
          print("❌ Server reported failure in deletion: ${data['error']}");
        }
      } else {
        print("❌ HTTP Error during message deletion: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ Error deleting message: $e");
    }
  }

  // ------------------- LOCAL DELETION STATUS UPDATE -------------------
  static Future<void> _updateMessageDeletionStatusLocal(String messageId, String role) async {
    try {
      final msg = _messageBox.values.firstWhereOrNull((m) => m.messageId == messageId);
      if (msg != null) {

        if (role == 'sender') {
          msg.isDeletedSender = 1;
        } else if (role == 'receiver') {
          msg.isDeletedReceiver = 1;
        }

        if (msg.isDeletedSender == 1 && msg.isDeletedReceiver == 1) {
          await _messageBox.delete(messageId);
          print("✅ Message deleted completely locally: $messageId");
        } else {
          await _messageBox.put(messageId, msg);
          print("✅ Message marked as deleted by $role locally: $messageId");
        }

        _newMessageController.add(msg);
      }
    } catch (e) {
      print("❌ Error updating local deletion status: $e");
    }
  }

  // ------------------- UTILITY METHODS -------------------
  static bool get isInitialized => _isInitialized;

  static Set<String> get uploadingMediaIds => _uploadingMediaIds;

  static void cancelMediaUpload(String tempId) {
    _uploadingMediaIds.remove(tempId);
    print("🛑 Media upload cancelled: $tempId");
  }

  // ✅ Get full media URL with automatic decryption
  static String getMediaUrl(String mediaPath) {
    if (mediaPath.startsWith('http')) {
      return mediaPath;
    } else if (mediaPath.startsWith('/uploads/')) {
      // Server automatically decrypts via /media/file/:filename endpoint
      final fileName = mediaPath.split('/').last;
      return '${Config.baseNodeApiUrl}/media/file/$fileName';
    } else {
      return mediaPath;
    }
  }
}