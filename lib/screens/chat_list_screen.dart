import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/user_status_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import '../theme.dart';

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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.debugChats();
    });
    _statusService.updateStatus(true);
  }

  @override
  void dispose() {
    _statusService.updateStatus(false);
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

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} Hours';
    } else {
      return '${difference.inDays} Days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          'Chat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Top navigation bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                _buildNavItem('Chat', 0),
                _buildNavItem('Activities', 1),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: 'Message:',
                  hintStyle: TextStyle(color: accentColor),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: accentColor),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) => setState(() {
                  searchQuery = val.trim().toLowerCase();
                }),
              ),
            ),
          ),

          // Chat list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = _chatService.filterOtherUsers(snapshot.data!);

                final filteredUsers = allUsers.where((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final name =
                      ((userData['name'] ??
                                  userData['displayName'] ??
                                  userData['email'] ??
                                  'Unknown')
                              as String)
                          .toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: TextStyle(color: accentColor),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey.shade300,
                    indent: 80,
                  ),
                  itemBuilder: (context, index) {
                    final userDoc = filteredUsers[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final otherUserId = userDoc.id;
                    final otherUserName =
                        userData['name'] ??
                        userData['displayName'] ??
                        userData['email'] ??
                        'Unknown';

                    final lastMessageTime =
                        userData['lastMessageTime'] ?? Timestamp.now();
                    final lastMessage =
                        userData['lastMessage'] ?? 'Start a conversation...';

                    return _buildChatItem(
                      name: otherUserName,
                      lastMessage: lastMessage,
                      time: _formatTimestamp(lastMessageTime),
                      isOnline: userData['isOnline'] == true,
                      hasUnread:
                          userData['unreadCount'] != null &&
                          userData['unreadCount'] > 0,
                      unreadCount: userData['unreadCount'] ?? 0,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        onPressed: _navigateToUsers,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNavItem(String title, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? primaryColor : accentColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem({
    required String name,
    required String lastMessage,
    required String time,
    required bool isOnline,
    required bool hasUnread,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1E2D),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(time, style: TextStyle(fontSize: 12, color: accentColor)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lastMessage,
                style: TextStyle(fontSize: 14, color: accentColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread && unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
