// lib/pages/chat_home.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:collection/collection.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/chat_service.dart';
import '../services/local_auth_service.dart';
import '../services/crypto_manager.dart';
import '../models/chat_model.dart';
import '../services/contact_service.dart';
import '../services/my_firebase_messaging_service.dart';
import 'chat_screen.dart';
import 'new_chat_page.dart';
import '../config.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  int _selectedIndex = 0;
  final Map<int, String> _userStatus = {};
  late StreamSubscription _userStatusSubscription;
  bool _contactsSynced = false;
  bool _notificationAsked = false;

  late final List<Widget> _screens = [
    ChatsTab(userStatus: _userStatus),
    const GroupsTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _startContactSync();
    _setupUserStatusListener();
    ChatService.ensureConnected();

    final userId = LocalAuthService.getUserId();
    if (userId != null) {
      ChatService.markAllMessagesAsDelivered(userId);
    }
  }

  void _setupUserStatusListener() {
    ChatService.ensureConnected();
    _userStatusSubscription = ChatService.onUserStatus.listen((statusData) {
      final userId = int.tryParse(statusData['userId']?.toString() ?? '');
      final status = statusData['status'] as String? ?? 'offline';
      if (userId != null) {
        setState(() {
          _userStatus[userId] = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _userStatusSubscription.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startContactSync() async {
    final userId = LocalAuthService.getUserId();
    if (userId == null) {
      print("Error: User ID is null. Cannot sync contacts.");
      return;
    }

    setState(() {
      _contactsSynced = false;
    });

    if (await fc.FlutterContacts.requestPermission()) {
      await ContactService.fetchPhoneContacts(ownerUserId: userId);
    }

    setState(() {
      _contactsSynced = true;
    });

    await MyFirebaseMessagingService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF075E54),
        title: const Text(
          "ZAKHIRA",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        actions: const [
          Icon(Icons.search, color: Colors.white),
          SizedBox(width: 16),
          Icon(Icons.more_vert, color: Colors.white),
          SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF075E54),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chats"),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: "Groups"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatPage()),
          );
        },
      )
          : null,
    );
  }
}

class ChatsTab extends StatefulWidget {
  final Map<int, String> userStatus;
  const ChatsTab({super.key, required this.userStatus});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  static final _cryptoManager = CryptoManager();

  // ✅ WhatsApp style message display for home screen
  String _getDisplayMessage(Message message) {
    // ✅ Media message (encrypted or direct)
    if (message.messageType == 'media' ||
        message.messageType == 'encrypted_media' ||
        (message.messageId.toString().startsWith('temp_') &&
            message.messageType == 'media')) {
      return "📷 Photo";
    }

    // ✅ Encrypted message - check if it's media
    if (message.messageType == 'encrypted') {
      try {
        final decryptedData = _cryptoManager.decryptAndDecompress(message.messageContent);
        final decodedData = jsonDecode(decryptedData.toString());
        if (decodedData['type'] == 'media') {
          return "📷 Photo";
        }
      } catch (e) {
        // If decryption fails, check if it contains media indicators
        if (message.messageContent.contains('media') || message.messageContent == 'media') {
          return "📷 Photo";
        }
      }
    }

    // ✅ Regular text message - try to decrypt if encrypted
    if (message.messageType == 'encrypted') {
      try {
        final decryptedData = _cryptoManager.decryptAndDecompress(message.messageContent);
        final decodedData = jsonDecode(decryptedData.toString());
        return decodedData['content'] ?? "Message";
      } catch (e) {
        return "Message";
      }
    }

    // ✅ Plain text message
    return message.messageContent.isNotEmpty ? message.messageContent : "Message";
  }

  Future<Contact> _createContactFromMessage(
      Message message, int currentUserId) async {
    final otherUserId = message.senderId == currentUserId
        ? message.receiverId
        : message.senderId;
    final otherUserPhone = message.senderId == currentUserId
        ? message.receiverPhoneNumber
        : message.senderPhoneNumber;

    String displayName = "";

    if (otherUserPhone != null && otherUserPhone.isNotEmpty) {
      final localContactName =
      await ContactService.getContactNameByPhoneNumber(otherUserPhone);
      if (localContactName != null && localContactName.isNotEmpty) {
        displayName = localContactName;
      }
    }

    if (displayName.isEmpty) {
      final otherUserName = message.senderId == currentUserId
          ? message.receiverName
          : message.senderName;
      if (otherUserName != null && otherUserName.isNotEmpty) {
        displayName = otherUserName;
      }
    }

    if (displayName.isEmpty && otherUserPhone != null && otherUserPhone.isNotEmpty) {
      displayName = otherUserPhone;
    }

    if (displayName.isEmpty) {
      displayName = "User $otherUserId";
    }

    // ✅ Use the new display method
    final lastMessageContent = _getDisplayMessage(message);

    return Contact(
      id: otherUserId,
      name: displayName,
      lastMessage: lastMessageContent,
      lastMessageTime: message.timestamp,
      chatId: message.chatId,
      phoneNumber: otherUserPhone,
    );
  }

  Future<void> _onRefresh() async {
    final messagesBox = Hive.box<Message>('messages');
    final chatIds = messagesBox.values.map((msg) => msg.chatId).whereType<int>().toSet();

    await SchedulerBinding.instance.endOfFrame;

    for (var chatId in chatIds) {
      await ChatService.fetchMessages(chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Message>>(
      valueListenable: Hive.box<Message>('messages').listenable(),
      builder: (context, box, _) {
        final userId = LocalAuthService.getUserId();
        if (userId == null) {
          return const Center(child: Text("Please login to see chats."));
        }

        final Map<int, Message> latestMessages = {};
        for (var message in box.values) {
          final otherUserId =
          message.senderId == userId ? message.receiverId : message.senderId;
          if (otherUserId > 0) {
            if (!latestMessages.containsKey(otherUserId) ||
                message.timestamp.isAfter(latestMessages[otherUserId]!.timestamp)) {
              latestMessages[otherUserId] = message;
            }
          }
        }

        if (latestMessages.isEmpty) {
          return const Center(child: Text("No chats yet. Start a new one!"));
        }

        return FutureBuilder<List<Contact>>(
          future: Future.wait(
            latestMessages.values
                .map((msg) => _createContactFromMessage(msg, userId))
                .toList(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print("FutureBuilder Error: ${snapshot.error}");
              return Center(
                  child: Text("Error loading chats: ${snapshot.error}"));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text("No chats available. Start a new one!"));
            }

            final sortedContacts = snapshot.data!
              ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: sortedContacts.length,
                itemBuilder: (context, index) {
                  final contact = sortedContacts[index];
                  final latestMessage = latestMessages.values.firstWhereOrNull((msg) => msg.chatId == contact.chatId);
                  final isOnline = widget.userStatus[contact.id] == 'online';

                  return ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(contact.name),
                    subtitle: Row(
                      children: [
                        if (latestMessage != null)
                          _buildTickIcon(latestMessage, userId),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isOnline ? 'Online' : (contact.lastMessage ?? "No message"),
                            style: TextStyle(
                              color: isOnline ? Colors.green.shade600 : Colors.grey,
                              fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      _formatTime(contact.lastMessageTime),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      if (contact.chatId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Chat ID not found.")),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: contact.chatId!,
                            otherUserId: contact.id,
                            otherUserName: contact.name,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (today == messageDate) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  Widget _buildTickIcon(Message message, int currentUserId) {
    if (message.senderId != currentUserId) {
      return const SizedBox.shrink();
    }

    if (message.isRead == 1) {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    } else if (message.isDelivered == 1) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else {
      return const Icon(Icons.check, size: 16, color: Colors.grey);
    }
  }
}

class Contact {
  final int id;
  final String name;
  final String? lastMessage;
  final DateTime lastMessageTime;
  final int? chatId;
  final String? phoneNumber;

  Contact({
    required this.id,
    required this.name,
    this.lastMessage,
    required this.lastMessageTime,
    this.chatId,
    this.phoneNumber,
  });
}

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Groups will appear here"));
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Profile info will appear here"));
  }
}