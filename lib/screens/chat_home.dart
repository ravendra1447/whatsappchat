// lib/pages/chat_home.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:collection/collection.dart'; // Add this import
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

import '../services/chat_service.dart';
import '../services/local_auth_service.dart';
import '../services/crypto_manager.dart';
import '../models/chat_model.dart';
import '../services/contact_service.dart';
import '../services/my_firebase_messaging_service.dart';
import 'chat_screen.dart';
import 'new_chat_page.dart';
import '../config.dart'; // Add this import

// ✅ This main stateful widget now manages the user status map
class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  int _selectedIndex = 0;
  // 🆕 ऑनलाइन/ऑफलाइन स्टेटस स्टोर करने के लिए एक मैप
  final Map<int, String> _userStatus = {};
  late StreamSubscription _userStatusSubscription;
  bool _contactsSynced = false; // 🆕 Contacts sync status track करने के लिए
  bool _notificationAsked = false; // 🆕 Notification permission asked track करने के लिए

  // 🆕 _screens list now passes the userStatus map to ChatsTab
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
    ChatService.ensureConnected();// हर बार home खुलने पर online heartbeat चालू

    final userId = LocalAuthService.getUserId();
    if (userId != null) {
      ChatService.markAllMessagesAsDelivered(userId);
    }
  }

  // 🆕 New method to set up the status listener
  void _setupUserStatusListener() {
    ChatService.ensureConnected(); // Ensure connection and status heartbeat
    _userStatusSubscription = ChatService.onUserStatus.listen((statusData) {
      final userId = int.tryParse(statusData['userId']?.toString() ?? '');
      final status = statusData['status'] as String? ?? 'offline';
      if (userId != null) {
        setState(() {
          _userStatus[userId] = status;
          print("UI Updated for user $userId, status: $status");
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

    // 🆕 Contacts sync complete होने के बाद notification permission ask करें
    setState(() {
      _contactsSynced = true;
    });

    // 🆕 Contacts sync के बाद notification permission ask करें
    //await _askNotificationPermission();
    await MyFirebaseMessagingService.initialize();
  }

  // 🆕 Notification Permission Logic
  Future<void> _askNotificationPermission() async {
    if (_notificationAsked) return;

    // Contacts sync के बाद ही permission ask करें
    if (!_contactsSynced) return;

    debugPrint("🔔 Asking notification permission after contacts sync");

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Notification settings get करें
      NotificationSettings settings = await messaging.getNotificationSettings();

      // Agar permission नहीं दी गई है, तो request करें
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await _showNotificationPermissionDialog();
      } else {
        debugPrint("Notification permission already: ${settings.authorizationStatus}");
      }

    } catch (e) {
      debugPrint("Error asking notification permission: $e");
    }

    setState(() {
      _notificationAsked = true;
    });
  }

  Future<void> _showNotificationPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Colors.blue),
              SizedBox(width: 10),
              Text("Enable Notifications"),
            ],
          ),
          content: const Text(
            "Allow whatsappchat to send you notifications?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Don't Allow
              },
              child: const Text(
                "Don't Allow",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Allow
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text("Allow"),
            ),
          ],
        );
      },
    );

    // User ने Allow दबाया तो permission request करें
    if (result == true) {
      await _requestNotificationPermission();
    } else {
      debugPrint("User denied notification permission");
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: false,
      );

      debugPrint("Notification permission granted: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // FCM token get करें
        String? token = await messaging.getToken();
        debugPrint("FCM Token: $token");

        // Token को server पर save करें (अगर needed हो)
        await _saveFCMTokenToServer(token);
      }

    } catch (e) {
      debugPrint("Error requesting notification permission: $e");
    }
  }

  Future<void> _saveFCMTokenToServer(String? token) async {
    if (token == null) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) return;

      // अपने server API को call करें FCM token save करने के लिए
      final response = await http.post(
          Uri.parse("${Config.baseNodeApiUrl}/save_fcm_token"),
          body: {
            'user_id': userId.toString(),
            'fcm_token': token,
          }
      );

      if (response.statusCode == 200) {
        debugPrint("✅ FCM token saved to server");
      } else {
        debugPrint("❌ Failed to save FCM token");
      }

    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
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

/// ================= CHATS TAB =================
// 🆕 ChatsTab is now a StatefulWidget to receive the status map
class ChatsTab extends StatefulWidget {
  final Map<int, String> userStatus;
  const ChatsTab({super.key, required this.userStatus});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  static final _cryptoManager = CryptoManager();

  Future<Contact> _createContactFromMessage(
      Message message, int currentUserId) async {
    final otherUserId = message.senderId == currentUserId
        ? message.receiverId
        : message.senderId;
    final otherUserPhone = message.senderId == currentUserId
        ? message.receiverPhoneNumber
        : message.senderPhoneNumber;

    String displayName = "";
    String lastMessageContent = "Encrypted Message";

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

    if (message.messageType == 'encrypted' ||
        message.messageType == 'encrypted_media') {
      try {
        final decryptedData =
        await _cryptoManager.decryptAndDecompress(message.messageContent);
        lastMessageContent = decryptedData['content'] as String;
      } catch (e) {
        lastMessageContent = "[Decryption Failed]";
        print("❌ Decryption error for message ${message.messageId}: $e");
      }
    } else {
      lastMessageContent = message.messageContent;
    }

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
                message.timestamp
                    .isAfter(latestMessages[otherUserId]!.timestamp)) {
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
                  // Find the correct latest message for this specific contact's chat
                  final latestMessage = latestMessages.values.firstWhereOrNull((msg) => msg.chatId == contact.chatId);

                  // 🆕 Get the online status from the passed map
                  final isOnline = widget.userStatus[contact.id] == 'online';

                  return ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        // 🆕 Display online dot if user is online
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
                        // 🆕 Show 'Online' or 'Offline' status in subtitle
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
                      "${contact.lastMessageTime.hour.toString().padLeft(2, '0')}:${contact.lastMessageTime.minute.toString().padLeft(2, '0')}",
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

  /// Updated Tick Icon builder to show single, double, and blue ticks
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