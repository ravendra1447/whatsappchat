// import 'package:flutter/material.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// //import 'chat_screen.dart';
//  // ✅ Add missing import
//
// class SelectContactScreen extends StatefulWidget {
//   const SelectContactScreen({super.key});
//
//   @override
//   State<SelectContactScreen> createState() => _SelectContactScreenState();
// }
//
// class _SelectContactScreenState extends State<SelectContactScreen> {
//   List<Contact> contacts = [];
//   List<Contact> filtered = [];
//   bool loading = true;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadContacts();
//   }
//
//   Future<void> _loadContacts() async {
//     if (await FlutterContacts.requestPermission()) {
//       final data = await FlutterContacts.getContacts(
//         withProperties: true,
//         withPhoto: true,
//       );
//       setState(() {
//         contacts = data;
//         filtered = contacts;
//         loading = false;
//       });
//     } else {
//       Navigator.pop(context);
//     }
//   }
//
//   Future<void> _startChatWithContact(Contact contact) async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//
//     final phone =
//     contact.phones.isNotEmpty ? contact.phones.first.number.trim() : null;
//     if (phone == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No phone number available for this contact')),
//       );
//       return;
//     }
//
//     try {
//       // ✅ Check agar user already registered hai
//       final userSnapshot = await _firestore
//           .collection('users')
//           .where('phone', isEqualTo: phone)
//           .limit(1)
//           .get();
//
//       String otherUserId;
//
//       if (userSnapshot.docs.isEmpty) {
//         // ✅ Agar user registered nahi hai -> register kar do
//         final newUserRef = await _firestore.collection('users').add({
//           'name': contact.displayName,
//           'phone': phone,
//           'created_at': FieldValue.serverTimestamp(),
//         });
//         otherUserId = newUserRef.id;
//       } else {
//         otherUserId = userSnapshot.docs.first.id;
//       }
//
//       // ✅ Check agar chat already exist karti hai
//       final chatQuery = await _firestore
//           .collection('chats')
//           .where('participants', arrayContains: currentUser.uid)
//           .get();
//
//       String chatId = "";
//       for (var chat in chatQuery.docs) {
//         List participants = chat['participants'];
//         if (participants.contains(otherUserId)) {
//           chatId = chat.id;
//           break;
//         }
//       }
//
//       // if (chatId.isEmpty) {
//       //   // ✅ New chat create karo
//       //   final newChatRef = await _firestore.collection('chats').add({
//       //     'participants': [currentUser.uid, otherUserId],
//       //     'created_at': FieldValue.serverTimestamp(),
//       //     'last_message': '',
//       //     'last_message_time': FieldValue.serverTimestamp(),
//       //     'type': 'individual',
//       //   });
//       //   chatId = newChatRef.id;
//       // }
//
//       if (!mounted) return;
//       // Navigator.push(
//       //   context,
//       //   MaterialPageRoute(
//       //     builder: (_) => ChatScreen(
//       //       chatId: chatId,
//       //       name: contact.displayName,
//       //       senderId: currentUser.uid,
//       //       otherUserId: otherUserId,
//       //       phone: phone,
//       //       avatarBytes: contact.photoOrThumbnail,
//       //     ),
//       //   ),
//       // );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error starting chat: ${e.toString()}')),
//       );
//     }
//   }
//
//
//   Widget _buildTopOptions() {
//     return Column(
//       children: [
//         ListTile(
//           leading: const CircleAvatar(
//             backgroundColor: Color(0xFF25D366),
//             child: Icon(Icons.group, color: Colors.white),
//           ),
//           title: const Text("New group"),
//           onTap: () {
//
//           },
//         ),
//         ListTile(
//           leading: const CircleAvatar(
//             backgroundColor: Color(0xFF25D366),
//             child: Icon(Icons.person_add, color: Colors.white),
//           ),
//           title: const Text("New contact"),
//           trailing: const Icon(Icons.qr_code, color: Colors.black54),
//           onTap: () {},
//         ),
//         const Padding(
//           padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
//           child: Align(
//             alignment: Alignment.centerLeft,
//             child: Text(
//               "Contacts on WhatsApp",
//               style: TextStyle(
//                 color: Colors.grey,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "Select contact",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
//             ),
//             Text(
//               "${contacts.length} contacts",
//               style: const TextStyle(fontSize: 13, color: Colors.white70),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.search),
//             onPressed: () {
//               showSearch(
//                 context: context,
//                 delegate: ContactSearchDelegate(contacts, _startChatWithContact),
//               );
//             },
//           ),
//           IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
//         ],
//       ),
//       body: loading
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//         itemCount: filtered.length + 1,
//         itemBuilder: (context, index) {
//           if (index == 0) return _buildTopOptions();
//           final contact = filtered[index - 1];
//           return ListTile(
//             leading: (contact.photoOrThumbnail != null)
//                 ? CircleAvatar(
//               backgroundImage: MemoryImage(contact.photoOrThumbnail!),
//             )
//                 : const CircleAvatar(
//               backgroundColor: Color(0xFF25D366),
//               child: Icon(Icons.person, color: Colors.white),
//             ),
//             title: Text(contact.displayName),
//             subtitle: contact.phones.isNotEmpty
//                 ? Text(contact.phones.first.number)
//                 : const Text("No phone number"),
//             onTap: () => _startChatWithContact(contact),
//           );
//         },
//       ),
//     );
//   }
// }
//
// class ContactSearchDelegate extends SearchDelegate {
//   final List<Contact> contacts;
//   final Function(Contact) onTapContact;
//
//   ContactSearchDelegate(this.contacts, this.onTapContact);
//
//   BuildContext? get context => null;
//
//   @override
//   List<Widget>? buildActions(BuildContext context) {
//     return [
//       IconButton(icon: const Icon(Icons.clear), onPressed: () => query = "")
//     ];
//   }
//
//   @override
//   Widget? buildLeading(BuildContext context) {
//     return IconButton(
//       icon: const Icon(Icons.arrow_back),
//       onPressed: () => close(context, null),
//     );
//   }
//
//   @override
//   Widget buildResults(BuildContext context) {
//     final results = contacts
//         .where((c) =>
//     c.displayName.toLowerCase().contains(query.toLowerCase()) ||
//         (c.phones.isNotEmpty &&
//             c.phones.first.number
//                 .replaceAll(" ", "")
//                 .contains(query.replaceAll(" ", ""))))
//         .toList();
//
//     return _buildContactList(results);
//   }
//
//   @override
//   Widget buildSuggestions(BuildContext context) {
//     return buildResults(context);
//   }
//
//   Widget _buildContactList(List<Contact> results) {
//     return ListView(
//       children: results
//           .map((c) => ListTile(
//         leading: c.photoOrThumbnail != null
//             ? CircleAvatar(
//           backgroundImage: MemoryImage(c.photoOrThumbnail!),
//         )
//             : const CircleAvatar(
//           backgroundColor: Color(0xFF25D366),
//           child: Icon(Icons.person, color: Colors.white),
//         ),
//         title: Text(c.displayName),
//         subtitle:
//         c.phones.isNotEmpty ? Text(c.phones.first.number) : const Text(""),
//         onTap: () {
//           close(context!, c);
//           onTapContact(c); // ✅ directly start chat on tap
//         },
//       ))
//           .toList(),
//     );
//   }
// }
