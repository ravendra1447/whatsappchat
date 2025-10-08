// lib/screens/new_chat_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import '../services/chat_service.dart';
import '../services/local_auth_service.dart';
import 'chat_screen.dart';
import 'package:collection/collection.dart';

class NewChatPage extends StatefulWidget {
  final bool isForForwarding;
  const NewChatPage({super.key, this.isForForwarding = false});
  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  List<Contact> allContacts = [];
  String searchQuery = '';
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  static const int _contactsPerPage = 50;
  bool _isLoadingMore = false;
  bool _hasMoreContacts = true;
  List<Contact> _allHiveContacts = [];
  int _contactsLoadedCount = 0;

  late final VoidCallback _contactChangeListener;

  @override
  void initState() {
    super.initState();
    _loadInitialContacts();
    _scrollController.addListener(_onScroll);
    _contactChangeListener = () {
      _loadInitialContacts();
    };
    ContactService.contactChangeNotifier.addListener(_contactChangeListener);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    ContactService.contactChangeNotifier.removeListener(_contactChangeListener);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreContacts) {
      _loadMoreContacts();
    }
  }

  Future<void> _loadInitialContacts() async {
    final userId = LocalAuthService.getUserId();
    if (userId == null) return;

    _allHiveContacts = ContactService.getLocalContacts(ownerUserId: userId);

    if (mounted) {
      final initialContacts = _allHiveContacts.take(_contactsPerPage).toList();
      setState(() {
        allContacts = initialContacts;
        _contactsLoadedCount = initialContacts.length;
        _hasMoreContacts = _allHiveContacts.length > _contactsLoadedCount;
      });
    }

    try {
      await ContactService.fetchPhoneContacts(ownerUserId: userId);
    } catch (e) {
      print("Error fetching fresh contacts in background: $e");
    }
  }

  Future<void> _loadMoreContacts() async {
    if (!mounted || _isLoadingMore || !_hasMoreContacts) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextBatch = _allHiveContacts
        .skip(_contactsLoadedCount)
        .take(_contactsPerPage)
        .toList();

    if (nextBatch.isEmpty) {
      if (mounted) {
        setState(() {
          _hasMoreContacts = false;
          _isLoadingMore = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        allContacts.addAll(nextBatch);
        _contactsLoadedCount = allContacts.length;
        _hasMoreContacts = _allHiveContacts.length > _contactsLoadedCount;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      setState(() => searchQuery = q.trim().toLowerCase());
    });
  }

  Future<Map<String, List<Contact>>> getCategorizedContacts() async {
    List<Contact> filtered = _allHiveContacts.where((c) {
      final nameToShow = c.contactName.isNotEmpty ? c.contactName : c.contactPhone;
      return nameToShow.toLowerCase().contains(searchQuery) ||
          c.contactPhone.contains(searchQuery);
    }).toList();

    filtered.sort((a, b) {
      final aName = a.contactName.isNotEmpty ? a.contactName : a.contactPhone;
      final bName = b.contactName.isNotEmpty ? b.contactName : b.contactPhone;
      return aName.compareTo(bName);
    });

    if (widget.isForForwarding) {
      filtered = filtered.where((c) => c.isOnApp).toList();
    }

    final registered = filtered.where((c) => c.isOnApp).toList();
    final nonRegistered = filtered.where((c) => !c.isOnApp).toList();

    return {
      "registered": registered,
      "nonRegistered": nonRegistered,
    };
  }

  void _inviteUser(String phone) async {
    final Uri uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': 'Hey! Try Zakhira app for chatting.'},
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch SMS to $phone')));
      }
    }
  }

  Future<void> _openChat(Contact contact) async {
    if (contact.appUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("This user is not registered on app.")));
      }
      return;
    }
    try {
      final chatId = await ChatService.createChat(contact.appUserId!);
      if (!mounted) return;
      if (chatId != null) {
        if (widget.isForForwarding) {
          Navigator.pop(context, chatId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                otherUserId: contact.appUserId!,
                otherUserName: contact.contactName,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not open chat (chatId null)')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget buildContactList() {
    if (_allHiveContacts.isEmpty && !_isLoadingMore && searchQuery.isEmpty) {
      return const Center(child: Text('No contacts found.'));
    }

    return FutureBuilder<Map<String, List<Contact>>>(
      future: getCategorizedContacts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final registered = snapshot.data!["registered"]!;
        final nonRegistered = snapshot.data!["nonRegistered"]!;

        return ListView(
          controller: _scrollController,
          children: [
            if (registered.isNotEmpty)
              buildSection("Registered Users", registered),
            if (!widget.isForForwarding && nonRegistered.isNotEmpty)
              buildSection("Invite Friends", nonRegistered),
            if (_isLoadingMore)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }

  Widget buildSection(String title, List<Contact> contacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...contacts.map((c) => ListTile(
          leading: CircleAvatar(
              backgroundColor: c.isOnApp ? Colors.green : Colors.grey,
              child: const Icon(Icons.person, color: Colors.white)),
          title: Text(c.contactName.isNotEmpty ? c.contactName : c.contactPhone),
          subtitle: c.contactName.isNotEmpty ? Text(c.contactPhone) : null,
          trailing: c.isOnApp
              ? null
              : TextButton(
              onPressed: () => _inviteUser(c.contactPhone),
              child: const Text("Invite",
                  style: TextStyle(color: Colors.green))),
          onTap: () => _openChat(c),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isForForwarding ? "Forward to..." : "New Chat"),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                  hintText: "Search name or number",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[200]),
              onChanged: _onSearchChanged,
            ),
          ),
          if (!widget.isForForwarding) ...[
            ListTile(
                leading: const Icon(Icons.group, color: Colors.green),
                title: const Text("New Group"),
                onTap: () {}),
            ListTile(
                leading: const Icon(Icons.person_add, color: Colors.blue),
                title: const Text("New Contact"),
                onTap: () {}),
            const Divider(),
          ],
          Expanded(child: buildContactList()),
        ],
      ),
    );
  }
}