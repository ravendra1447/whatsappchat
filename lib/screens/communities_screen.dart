import 'package:flutter/material.dart';

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Communities"),
        backgroundColor: const Color(0xFF075E54),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "settings",
                child: Text("Settings"),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          // New Community Banner
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.green,
              child: Icon(Icons.group, color: Colors.white),
            ),
            title: const Text("New Community"),
            subtitle: const Text("Create a new community"),
            onTap: () {},
          ),
          const Divider(),

          // Example Community Group
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              backgroundImage:
              NetworkImage("https://via.placeholder.com/150"),
            ),
            title: const Text("Flutter Devs"),
            subtitle: const Text("Latest: Meeting tomorrow at 5 PM"),
            onTap: () {},
          ),
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              backgroundImage:
              NetworkImage("https://via.placeholder.com/150"),
            ),
            title: const Text("Job Alerts Group"),
            subtitle: const Text("Latest: New openings in IT sector"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
