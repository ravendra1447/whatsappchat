// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart'; // Hive-Flutter import (for listenable())
// import 'dart:developer';
// import 'package:collection/collection.dart'; // .firstOrNull के लिए
//
// // 🛑 ASSUMED IMPORTS (यह मानकर कि ये फाइलें आपके प्रोजेक्ट में मौजूद हैं)
// import '../models/chat_contact.dart'; // ChatContact Model
// import '../models/chat_model.dart'; // Message Model
// import '../models/contact.dart'; // Contact Model (Used in Isolate)
// import '../services/contact_service_optimized.dart'; // Optimized Contact Service
// import '../services/local_auth_service.dart'; // User ID के लिए
// import '../services/crypto_manager.dart'; // Decryption के लिए
// import 'chat_screen.dart'; // ChatScreen Navigation के लिए
//
// // Helper function: kisi bhi function ke execution time ko measure kare
// Future<T> measureExecutionTime<T>(String label, Future<T> Function() task) async {
//   final start = DateTime.now();
//   log('⏳ Start: $label');
//   final result = await task();
//   final end = DateTime.now();
//   final duration = end.difference(start).inMilliseconds;
//   log('✅ Done: $label (${duration}ms)');
//   return result;
// }
//
// // -------------------------------------------------------------------
// // CHATSTAB CLASS (Optimized and Fixed)
// // -------------------------------------------------------------------
// class ChatsTab extends StatefulWidget {
//   final Map<int, String> userStatus; // Online/offline status map (ChatHomePage से आता है)
//   const ChatsTab({super.key, required this.userStatus});
//
//   @override
//   State<ChatsTab> createState() => _ChatsTabState();
// }
//
// class _ChatsTabState extends State<ChatsTab> with SingleTickerProviderStateMixin {
//   List<ChatContact> _contactList = [];
//   bool _loading = true;
//   Timer? _debounceTimer;
//
//   // ✅ FIX: Type को ValueListenable<Box<Message>> रखें ताकि `_TypeError` न आए।
//   late final ValueListenable<Box<Message>> _messageBoxListener;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // 1. ✅ HIVE BOX CHANGES को Listen करना
//     _messageBoxListener = Hive.box<Message>('messages').listenable();
//     _messageBoxListener.addListener(_debouncedLoadChats); // Debounce से जोड़ा
//
//     // 2. Contact changes listen करना
//     ContactServiceOptimized.contactChangeNotifier.addListener(_debouncedLoadChats); // Debounce से जोड़ा
//
//     _initialLoadSequence();
//   }
//
//   // Debounce के साथ लोड करने के लिए (दोनों listeners के लिए)
//   void _debouncedLoadChats() {
//     _debounceTimer?.cancel();
//     _debounceTimer = Timer(const Duration(milliseconds: 500), () {
//       if (mounted) _loadChatsFromMessages();
//     });
//   }
//
//   // Async initialization sequence को हैंडल करने के लिए
//   Future<void> _initialLoadSequence() async {
//     await measureExecutionTime('TOTAL: ChatsTab Initial Load Sequence', () async {
//       await ContactServiceOptimized.buildContactMapAsync(incremental:true);
//
//       if (mounted) {
//         await _loadChatsFromMessages();
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _debounceTimer?.cancel();
//     // 🛑 दोनों Listeners को हटाना
//     _messageBoxListener.removeListener(_debouncedLoadChats);
//     ContactServiceOptimized.contactChangeNotifier.removeListener(_debouncedLoadChats);
//     super.dispose();
//   }
//
//   // Messages ko contacts me map kar ke chat list load karna
//   Future<void> _loadChatsFromMessages() async {
//     final messagesBox = Hive.box<Message>('messages');
//     final userId = LocalAuthService.getUserId();
//     if (userId == null) return;
//
//     // 1. Hive से messages लोड करना (I/O Operation)
//     final messages = await measureExecutionTime('1. Load Messages from Hive (I/O)', () async {
//       return messagesBox.values.toList();
//     });
//
//     if (messages.isEmpty) {
//       if (!mounted) return;
//       setState(() {
//         _contactList = [];
//         _loading = false;
//       });
//       return;
//     }
//
//     // 2. Heavy computation को background isolate मे run करना (CPU Operation)
//     final contactsFromMessages = await measureExecutionTime('2. Map Messages to Contacts (Isolate Compute)', () async {
//       return compute(
//         _mapMessagesToContactsCompute,
//         [messages, userId, ContactServiceOptimized.contactMapForCompute],
//       );
//     });
//
//     // Last message time ke basis par sort karna
//     contactsFromMessages.sort(
//           (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
//     );
//
//     if (!mounted) return;
//     setState(() {
//       _contactList = contactsFromMessages; // UI update
//       _loading = false;
//     });
//   }
//
//   // Background isolate function: messages से chat list (ChatContact) बनाता है
//   static List<ChatContact> _mapMessagesToContactsCompute(List<dynamic> args) {
//     final messages = args[0] as List<Message>;
//     final currentUserId = args[1] as int;
//     final contactMap = Map<String, Contact>.from(args[2]);
//
//     final Map<int, ChatContact> resultMap = {};
//     final Map<int, int> unreadCountMap = {};
//
//     for (var message in messages) {
//       final otherUserId = message.senderId == currentUserId
//           ? message.receiverId
//           : message.senderId;
//       final otherPhone = message.senderId == currentUserId
//           ? message.receiverPhoneNumber
//           : message.senderPhoneNumber;
//
//       String displayName = '';
//       if (otherPhone != null && otherPhone.isNotEmpty) {
//         displayName = contactMap[otherPhone]?.contactName ?? '';
//       }
//       if (displayName.isEmpty) {
//         displayName = message.senderId == currentUserId
//             ? message.receiverName ?? ''
//             : message.senderName ?? '';
//       }
//       if (displayName.isEmpty && otherPhone != null) displayName = otherPhone;
//       if (displayName.isEmpty) displayName = "User $otherUserId";
//
//       final lastMessage = _getDisplayMessageStatic(message);
//
//       // Result map update karna
//       final contact = resultMap[message.chatId ?? 0];
//       if (contact == null ||
//           message.timestamp.isAfter(contact.lastMessageTime)) {
//         resultMap[message.chatId ?? 0] = ChatContact(
//           id: otherUserId,
//           name: displayName,
//           lastMessage: lastMessage,
//           lastMessageTime: message.timestamp,
//           chatId: message.chatId,
//           phoneNumber: otherPhone,
//         );
//       }
//
//       // 🔸 Unread count increase
//       if (message.receiverId == currentUserId && (message.isRead != true)) {
//         unreadCountMap[message.chatId ?? 0] =
//             (unreadCountMap[message.chatId ?? 0] ?? 0) + 1;
//       }
//     }
//
//     // Unread count assign karna
//     final result = resultMap.values.toList();
//     for (var c in result) {
//       c.unreadCount = unreadCountMap[c.chatId ?? 0] ?? 0;
//     }
//     return result;
//   }
//
//   // Message ko display के लिए prepare karna (media, encrypted etc.)
//   static String _getDisplayMessageStatic(Message message) {
//     try {
//       if (message.messageType == 'media' ||
//           message.messageType == 'encrypted_media' ||
//           (message.messageId.toString().startsWith('temp_') &&
//               message.messageType == 'media')) {
//         return "📷 Photo";
//       }
//
//       if (message.messageType == 'encrypted') {
//         final decryptedData =
//         CryptoManager().decryptAndDecompress(message.messageContent);
//         final decoded = jsonDecode(decryptedData.toString());
//         if (decoded['type'] == 'media') return "📷 Photo";
//         return decoded['content'] ?? "Message";
//       }
//
//       return message.messageContent.isNotEmpty
//           ? message.messageContent
//           : "Message";
//     } catch (_) {
//       return "Message";
//     }
//   }
//
//   // -----------------------------------------------------------
//   // ✅ DOUBLE TICK LOGIC
//   // -----------------------------------------------------------
//   Widget _buildTickIcon(Message latestMessage, int currentUserId) {
//     if (latestMessage.senderId != currentUserId) {
//       return const SizedBox.shrink();
//     }
//     if (latestMessage.chatId == null) {
//       return const SizedBox.shrink();
//     }
//     // Read Status (Double Blue Tick)
//     if (latestMessage.isRead == 1) {
//       return const Icon(Icons.done_all, size: 16, color: Colors.blue);
//     }
//     // Delivered Status (Double Grey Tick)
//     else if (latestMessage.isDelivered == 1) {
//       return const Icon(Icons.done_all, size: 16, color: Colors.grey);
//     }
//     // Sent/Pending Status (Single Grey Tick)
//     else {
//       return const Icon(Icons.check, size: 16, color: Colors.grey);
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final currentUserId = LocalAuthService.getUserId() ?? 0;
//
//     if (_loading) return const Center(child: CircularProgressIndicator());
//     if (_contactList.isEmpty) {
//       return const Center(child: Text("अभी कोई चैट नहीं है। नई चैट शुरू करें!"));
//     }
//
//     // Chat list UI
//     return ListView.builder(
//       physics: const BouncingScrollPhysics(),
//       itemCount: _contactList.length,
//       itemBuilder: (context, index) {
//         final contact = _contactList[index];
//         final isOnline = widget.userStatus[contact.id] == 'online';
//         final unread = contact.unreadCount;
//
//         // Tick Icon के लिए latestMessage को Hive से लुकअप करें
//         final latestMessage = Hive.box<Message>('messages')
//             .values
//             .where((msg) => msg.chatId == contact.chatId)
//             .where((msg) => msg.timestamp == contact.lastMessageTime)
//             .firstOrNull; // collection/collection.dart से आता है
//
//
//         return ListTile(
//           leading: Stack(
//             children: [
//               // Default avatar
//               const CircleAvatar(
//                 backgroundColor: Colors.grey,
//                 child: Icon(Icons.person, color: Colors.white),
//               ),
//               // Online indicator
//               if (isOnline)
//                 Positioned(
//                   right: 0,
//                   bottom: 0,
//                   child: Container(
//                     width: 12,
//                     height: 12,
//                     decoration: BoxDecoration(
//                       color: Colors.green,
//                       shape: BoxShape.circle,
//                       border: Border.all(color: Colors.white, width: 2),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           title: Text(contact.name), // Contact name
//           subtitle: Row(
//             children: [
//               // 1. ✅ Tick Icon
//               if (latestMessage != null)
//                 _buildTickIcon(latestMessage, currentUserId),
//               const SizedBox(width: 4),
//
//               // 2. Message Text (Online Status + Last Message)
//               Expanded(
//                 child: Text(
//                   isOnline ? 'Online' : (contact.lastMessage ?? "No message"),
//                   style: TextStyle(
//                     color: isOnline ? Colors.green.shade600 : Colors.grey,
//                     fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//           trailing: Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 _formatTime(contact.lastMessageTime), // Last message time
//                 style: const TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//               const SizedBox(height: 4),
//               // 🔹 Animated unread badge
//               AnimatedScale(
//                 duration: const Duration(milliseconds: 250),
//                 curve: Curves.elasticOut,
//                 scale: unread > 0 ? 1.0 : 0.0,
//                 child: unread > 0
//                     ? Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 6, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: Colors.green,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     '$unread',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 11,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 )
//                     : const SizedBox.shrink(),
//               ),
//             ],
//           ),
//           onTap: () {
//             if (contact.chatId == null) return;
//             // Chat screen open karna
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => ChatScreen(
//                   chatId: contact.chatId!,
//                   otherUserId: contact.id,
//                   otherUserName: contact.name,
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   // Timestamp ko readable format me convert karna
//   String _formatTime(DateTime timestamp) {
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
//
//     if (today == messageDate) {
//       // Aaj ke message ke liye HH:mm
//       return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
//     } else {
//       // Date format: dd/MM
//       return '${timestamp.day}/${timestamp.month}';
//     }
//   }
// }