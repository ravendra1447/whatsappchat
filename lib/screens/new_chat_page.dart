// lib/screens/new_chat_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import '../services/chat_service.dart';
import '../services/local_auth_service.dart';
import 'chat_screen.dart';

class NewChatPage extends StatefulWidget {
  final bool isForForwarding;
  const NewChatPage({super.key, this.isForForwarding = false});
  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  // ✅ ULTRA FAST VARIABLES
  late final Box<Contact> _contactBox;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<Contact>> _filteredContacts = ValueNotifier([]);
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  Timer? _debounce;

  // ✅ LAZY LOADING VARIABLES
  final int _visibleItemCount = 30;
  int _currentDisplayCount = 0;
  List<Contact> _allContacts = [];

  // ✅ LOADING STATES
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  final Stopwatch _loadTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    _contactBox = Hive.box<Contact>('contacts');

    // ✅ START LOADING TIMER
    _loadTimer.start();

    // ✅ IMMEDIATE LOAD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContactsInstantly();
    });

    _contactBox.listenable().addListener(_onHiveDataChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _filteredContacts.dispose();
    _searchQuery.dispose();
    _contactBox.listenable().removeListener(_onHiveDataChanged);
    _loadTimer.stop();
    super.dispose();
  }

  // ✅ ULTRA FAST CONTACT LOADING WITH SMART LOADING INDICATOR
  void _loadContactsInstantly() {
    final userId = LocalAuthService.getUserId();
    if (userId == null) return;

    // ✅ SHOW LOADING ONLY IF IT TAKES TIME
    if (_loadTimer.elapsedMilliseconds > 100) { // 100ms से ज्यादा लगे तो loading दिखाएं
      setState(() {
        _isInitialLoading = true;
      });
    }

    // ✅ DIRECT HIVE ACCESS
    _allContacts = _contactBox.values
        .where((contact) =>
    contact.ownerUserId == userId &&
        !contact.isDeleted)
        .toList();

    // ✅ RESET DISPLAY COUNT
    _currentDisplayCount = _visibleItemCount;

    // ✅ IMMEDIATE UI UPDATE
    _filteredContacts.value = _allContacts;

    // ✅ HIDE LOADING AFTER DATA IS READY
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        _loadTimer.stop();
      }
    });
  }

  void _onHiveDataChanged() {
    final userId = LocalAuthService.getUserId();
    if (userId != null) {
      _loadContactsInstantly();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), () {
      _searchQuery.value = query.trim().toLowerCase();
      _applySearchFilter();
    });
  }

  // ✅ OPTIMIZED SEARCH FILTER
  void _applySearchFilter() {
    final query = _searchQuery.value;

    if (query.isEmpty) {
      _filteredContacts.value = _allContacts;
      _currentDisplayCount = _visibleItemCount;
      return;
    }

    // ✅ FAST FILTERING
    final filtered = _allContacts.where((contact) {
      final nameMatch = contact.contactName.toLowerCase().contains(query);
      final phoneMatch = contact.contactPhone.contains(query);
      return nameMatch || phoneMatch;
    }).toList();

    _filteredContacts.value = filtered;
    _currentDisplayCount = _visibleItemCount;
  }

  // ✅ FIXED: SAFE VISIBLE CONTACTS EXTRACTION
  List<Contact> _getVisibleContacts(List<Contact> contacts) {
    if (contacts.isEmpty) return [];

    final endIndex = _currentDisplayCount.clamp(0, contacts.length);
    return contacts.sublist(0, endIndex);
  }

  // ✅ LOAD MORE CONTACTS WITH LOADING INDICATOR
  void _loadMoreContacts() {
    final currentFiltered = _filteredContacts.value;

    if (_currentDisplayCount >= currentFiltered.length || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // ✅ SIMULATE LOADING DELAY FOR BETTER UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentDisplayCount += _visibleItemCount;
          _currentDisplayCount = _currentDisplayCount.clamp(0, currentFiltered.length);
          _isLoadingMore = false;
        });
      }
    });
  }

  // ✅ SMART LOADING INDICATOR
  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF075E54)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading ${_allContacts.length} contacts...',
            style: const TextStyle(
              color: Color(0xFF075E54),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_allContacts.length} contacts found',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ULTRA FAST CONTACT LIST WITH LOADING STATES
  Widget _buildContactList() {
    // ✅ SHOW LOADING IF INITIAL LOAD IS TAKING TIME
    if (_isInitialLoading) {
      return _buildLoadingIndicator();
    }

    return ValueListenableBuilder<List<Contact>>(
      valueListenable: _filteredContacts,
      builder: (context, filteredContacts, child) {
        if (filteredContacts.isEmpty && _searchQuery.value.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contacts, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No contacts found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Sync your phone contacts to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (filteredContacts.isEmpty && _searchQuery.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No contacts found for "${_searchQuery.value}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // ✅ GET VISIBLE CONTACTS FOR EACH CATEGORY
        final registeredContacts = filteredContacts.where((c) => c.isOnApp).toList();
        final nonRegisteredContacts = filteredContacts.where((c) => !c.isOnApp).toList();

        final visibleRegistered = _getVisibleContacts(registeredContacts);
        final visibleNonRegistered = _getVisibleContacts(nonRegisteredContacts);

        final hasMoreRegistered = _currentDisplayCount < registeredContacts.length;
        final hasMoreNonRegistered = _currentDisplayCount < nonRegisteredContacts.length;
        final hasMoreContacts = hasMoreRegistered || hasMoreNonRegistered;

        return Column(
          children: [
            // ✅ CONTACTS COUNT INDICATOR
            if (filteredContacts.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${_currentDisplayCount.clamp(0, filteredContacts.length)} of ${filteredContacts.length} contacts',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.value.isNotEmpty)
                      Text(
                        'Search: "${_searchQuery.value}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF075E54),
                        ),
                      ),
                  ],
                ),
              ),

            // ✅ CONTACTS LIST
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollEndNotification &&
                      scrollNotification.metrics.extentAfter < 100 &&
                      hasMoreContacts &&
                      !_isLoadingMore) {
                    _loadMoreContacts();
                  }
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: [
                    if (visibleRegistered.isNotEmpty)
                      _buildSection("Registered on Zakhira", visibleRegistered, hasMoreRegistered),

                    if (!widget.isForForwarding && visibleNonRegistered.isNotEmpty)
                      _buildSection("Invite to Zakhira", visibleNonRegistered, hasMoreNonRegistered),

                    if (_isLoadingMore)
                      _buildLoadMoreLoader(),

                    if (hasMoreContacts && !_isLoadingMore)
                      _buildLoadMoreButton(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ OPTIMIZED SECTION BUILDER
  Widget _buildSection(String title, List<Contact> contacts, bool hasMore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF075E54),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  contacts.length.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF075E54),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...contacts.map((contact) => ContactListItem(
          contact: contact,
          isForForwarding: widget.isForForwarding,
          onInvite: () => _inviteUser(contact.contactPhone),
          onTap: () => _openChat(contact),
        )),

        if (hasMore && !_isLoadingMore)
          const SizedBox(height: 8),
      ],
    );
  }

  // ✅ LOAD MORE BUTTON
  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _loadMoreContacts,
          icon: const Icon(Icons.expand_more, size: 20),
          label: const Text('Load More Contacts'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF075E54),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ LOAD MORE LOADER
  Widget _buildLoadMoreLoader() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF075E54)),
            ),
            SizedBox(height: 8),
            Text(
              'Loading more contacts...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
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

  // ✅ FAST CHAT OPENING
  Future<void> _openChat(Contact contact) async {
    if (contact.appUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This user is not registered on app.")),
      );
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
                otherUserName: contact.contactName.isNotEmpty
                    ? contact.contactName
                    : contact.contactPhone,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create chat')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
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
          // ✅ OPTIMIZED SEARCH
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search contacts...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // ✅ QUICK ACTIONS
          if (!widget.isForForwarding) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.group,
                      label: "New Group",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("New Group feature coming soon")),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.person_add,
                      label: "New Contact",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("New Contact feature coming soon")),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24.0),
          ],

          // ✅ INSTANT CONTACTS LIST WITH SMART LOADING
          Expanded(
            child: _buildContactList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF075E54)),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ✅ ULTRA OPTIMIZED CONTACT ITEM
class ContactListItem extends StatelessWidget {
  final Contact contact;
  final bool isForForwarding;
  final VoidCallback onInvite;
  final VoidCallback onTap;

  const ContactListItem({
    super.key,
    required this.contact,
    required this.isForForwarding,
    required this.onInvite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contact.isOnApp
              ? const Color(0xFF25D366)
              : Colors.grey,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          contact.contactName.isNotEmpty
              ? contact.contactName
              : contact.contactPhone,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: contact.contactName.isNotEmpty
            ? Text(contact.contactPhone)
            : null,
        trailing: contact.isOnApp
            ? const Icon(Icons.chat, color: Color(0xFF075E54))
            : TextButton(
          onPressed: onInvite,
          child: const Text(
            "INVITE",
            style: TextStyle(
              color: Color(0xFF25D366),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}