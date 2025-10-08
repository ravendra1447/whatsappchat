import 'package:flutter/material.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calls"),
        backgroundColor: const Color(0xFF075E54),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          // Create Call Link
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.green,
              child: Icon(Icons.link, color: Colors.white),
            ),
            title: const Text("Create call link"),
            subtitle: const Text("Share a link for your WhatsApp call"),
            onTap: () {},
          ),
          const Divider(),

          // Recent Calls
          _callTile(
            name: "Salman Bhai",
            time: "Yesterday, 9:20 PM",
            isIncoming: true,
          ),
          _callTile(
            name: "Suneel Raja",
            time: "Today, 10:30 AM",
            isIncoming: false,
          ),
          _callTile(
            name: "Bal Karan Patel",
            time: "Today, 1:05 PM",
            isIncoming: true,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add_call),
        onPressed: () {},
      ),
    );
  }

  Widget _callTile({
    required String name,
    required String time,
    required bool isIncoming,
  }) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage("https://via.placeholder.com/150"),
      ),
      title: Text(name),
      subtitle: Row(
        children: [
          Icon(
            isIncoming ? Icons.call_received : Icons.call_made,
            color: isIncoming ? Colors.red : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(time),
        ],
      ),
      trailing: const Icon(Icons.call, color: Colors.green),
      onTap: () {},
    );
  }
}
