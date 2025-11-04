import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';

import '../services/user_status_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  
  final ChatService _chatService = ChatService();
  final UserStatusService _statusService = UserStatusService();
  final TextEditingController searchController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.debugChats();
    });
    _statusService.updateStatus(true); // mark user online
  }

  @override
  void dispose() {
    _statusService.updateStatus(false); // mark user offline
    super.dispose();
  }

  void _refreshChats() {
    _chatService.debugChats();
    setState(() {});
  }

  void _navigateToUsers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find Users'),
        content: const Text(
          'This feature is coming soon! For now, you need to know someone\'s user ID to start a chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => setState(() {
                searchQuery = val.trim().toLowerCase();
              }),
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshChats),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
  stream: _chatService.getUsersStream(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter out current user
    final allUsers = _chatService.filterOtherUsers(snapshot.data!);

    // Apply search
    final filteredUsers = allUsers.where((doc) {
      final userData = doc.data() as Map<String, dynamic>;
      final name = ((userData['name'] ?? 
                    userData['displayName'] ?? 
                    userData['email'] ?? 
                    'Unknown') as String)
                  .toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final userDoc = filteredUsers[index];
        final userData = userDoc.data() as Map<String, dynamic>;
        final otherUserId = userDoc.id;
        final otherUserName = userData['name'] ?? 
                            userData['displayName'] ?? 
                            userData['email'] ?? 
                            'Unknown';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: userData['photoURL'] != null
                ? NetworkImage(userData['photoURL'])
                : null,
            child: userData['photoURL'] == null
                ? Text(otherUserName[0].toUpperCase())
                : null,
          ),
          title: Text(otherUserName),
          subtitle: Text(userData['isOnline'] == true ? 'Online' : 'Offline'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatWith: otherUserName,
                  chatWithId: otherUserId,
                ),
              ),
            );
          },
        );
      },
    );
  },
),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToUsers,
        child: const Icon(Icons.add),
      ),
    );
  }
}
