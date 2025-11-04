// import 'dart:typed_data';
// import 'dart:convert'; // for base64Encode & jsonDecode
// import 'package:http/http.dart' as http;

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/message_model.dart';

// class ChatService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // -----------------------
//   // CONNECTION & DEBUG
//   // -----------------------
//   bool get isConnected => _auth.currentUser != null;

//   void debugChats() async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) {
//       print('❌ No user logged in');
//       return;
//     }

//     print('🔍 Debugging chats for user: ${currentUser.uid}');

//     try {
//       final snapshot = await _firestore
//           .collection('chats')
//           .where('participants', arrayContains: currentUser.uid)
//           .get();

//       print('📊 Found ${snapshot.docs.length} chat documents:');

//       if (snapshot.docs.isEmpty) {
//         print('📭 No chat documents found in Firestore');
//       } else {
//         for (var doc in snapshot.docs) {
//           print('Chat ID: ${doc.id}');
//           print('Data: ${doc.data()}');
//           print('---');
//         }
//       }
//     } catch (e) {
//       print('❌ Error debugging chats: $e');
//     }
//   }

//   // -----------------------
//   // USERS
//   // -----------------------
//   Stream<QuerySnapshot> getUsersStream() {
//     if (!isConnected) return const Stream.empty();

//     try {
//       return _firestore.collection('users').snapshots();
//     } catch (e) {
//       print('❌ Error getting users stream: $e');
//       return const Stream.empty();
//     }
//   }

//   List<QueryDocumentSnapshot> filterOtherUsers(QuerySnapshot snapshot) {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return [];
//     return snapshot.docs.where((doc) => doc.id != currentUser.uid).toList();
//   }

//   // -----------------------
//   // CHAT LIST
//   // -----------------------
//   Stream<QuerySnapshot> getChatListStream() {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return const Stream.empty();

//     try {
//       return _firestore
//           .collection('chats')
//           .where('participants', arrayContains: currentUser.uid)
//           .snapshots();
//     } catch (e) {
//       print('❌ Error creating chat list stream: $e');
//       return const Stream.empty();
//     }
//   }

//   // -----------------------
//   // CHAT MESSAGES
//   // -----------------------
//   String getChatId(String user1, String user2) {
//     return user1.hashCode <= user2.hashCode
//         ? '${user1}_$user2'
//         : '${user2}_$user1';
//   }

//   Future<void> sendMessage(String receiverId, String messageText) async {
//     if (!isConnected) throw Exception('Not connected to Firebase');

//     final currentUser = _auth.currentUser!;
//     if (messageText.trim().isEmpty) return;

//     final chatId = getChatId(currentUser.uid, receiverId);

//     final message = Message(
//       id: '',
//       senderId: currentUser.uid,
//       receiverId: receiverId,
//       message: messageText.trim(),
//       timestamp: DateTime.now(),
//       status: "sent",
//     );

//     try {
//       final batch = _firestore.batch();

//       final messageRef =
//           _firestore.collection('chats').doc(chatId).collection('messages').doc();
//       batch.set(messageRef, message.toMap());

//       final chatRef = _firestore.collection('chats').doc(chatId);
//       batch.set(chatRef, {
//         'participants': [currentUser.uid, receiverId],
//         'lastMessage': messageText,
//         'lastMessageTime': FieldValue.serverTimestamp(),
//         'lastMessageSender': currentUser.uid,
//         'updatedAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));

//       await batch.commit();
//       print('✅ Message sent successfully');
//     } catch (e) {
//       print('❌ Error sending message: $e');
//       rethrow;
//     }
//   }

//   // -----------------------
//   // SEND FILE MESSAGE (WEB) via Cloudinary
//   // -----------------------
//   Future<void> sendFileMessageWeb(
//       String receiverId, String fileName, Uint8List fileBytes) async {
//     final currentUser = _auth.currentUser!;
//     final chatId = getChatId(currentUser.uid, receiverId);

//     try {
//       // 1️⃣ Upload to Cloudinary
//       final cloudName = 'YOUR_CLOUDINARY_CLOUD_NAME';
//       final uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';
//       final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');

//       final base64File = base64Encode(fileBytes);

//       final response = await http.post(url, body: {
//         'file': 'data:application/octet-stream;base64,$base64File',
//         'upload_preset': uploadPreset,
//         'public_id': 'uploads/$fileName',
//       });

//       if (response.statusCode != 200 && response.statusCode != 201) {
//         throw Exception('Cloudinary upload failed: ${response.body}');
//       }

//       final data = jsonDecode(response.body);
//       final downloadUrl = data['secure_url'];

//       // 2️⃣ Create Firestore message
//       final message = Message(
//         id: '',
//         senderId: currentUser.uid,
//         receiverId: receiverId,
//         message: '',
//         fileUrl: downloadUrl,
//         timestamp: DateTime.now(),
//         status: "sent",
//       );

//       final batch = _firestore.batch();

//       final messageRef =
//           _firestore.collection('chats').doc(chatId).collection('messages').doc();
//       batch.set(messageRef, message.toMap());

//       final chatRef = _firestore.collection('chats').doc(chatId);
//       batch.set(chatRef, {
//         'participants': [currentUser.uid, receiverId],
//         'lastMessage': '[File]',
//         'lastMessageTime': FieldValue.serverTimestamp(),
//         'lastMessageSender': currentUser.uid,
//         'updatedAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));

//       await batch.commit();
//       print('✅ File message sent successfully via Cloudinary: $fileName');
//     } catch (e) {
//       print('❌ Error sending file via Cloudinary: $e');
//       rethrow;
//     }
//   }

//   // -----------------------
//   // STREAM MESSAGES
//   // -----------------------
//   Stream<List<Message>> getChatStream(String receiverId) {
//     final currentUser = _auth.currentUser!;
//     final chatId = getChatId(currentUser.uid, receiverId);
//     return getChatStreamByChatId(chatId);
//   }

//   Stream<List<Message>> getChatStreamByChatId(String chatId) {
//     if (!isConnected) return Stream.value([]);

//     try {
//       return _firestore
//           .collection('chats')
//           .doc(chatId)
//           .collection('messages')
//           .orderBy('timestamp', descending: true)
//           .snapshots()
//           .map((snapshot) {
//         return snapshot.docs.map((doc) {
//           return Message.fromMap(doc.data(), doc.id);
//         }).toList();
//       });
//     } catch (e) {
//       print('❌ Error creating message stream: $e');
//       return Stream.value([]);
//     }
//   }

//   Future<void> markMessageAsSeen(String chatId, String messageId) async {
//     if (messageId.trim().isEmpty) return;
//     try {
//       await _firestore
//           .collection('chats')
//           .doc(chatId)
//           .collection('messages')
//           .doc(messageId)
//           .update({'status': 'seen'});
//     } catch (e) {
//       print('❌ Error marking message as seen: $e');
//     }
//   }
// }

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatWith;
  final String chatWithId;

  const ChatScreen({super.key, required this.chatWith, required this.chatWithId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await _chatService.sendMessage(widget.chatWithId, text);
    _messageController.clear();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes!;
      final fileName = file.name;

      await _chatService.sendFileMessageWeb(widget.chatWithId, fileName, bytes);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _chatService.getCurrentUserId();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(child: Text(widget.chatWith[0].toUpperCase())),
            const SizedBox(width: 10),
            Text(widget.chatWith),
            const SizedBox(width: 10),
            // Online/Offline status (fake here, you can use real status from Firestore)
            StreamBuilder(
              stream: _chatService.getUsersStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final userDoc = (snapshot.data as dynamic).docs.firstWhere(
                    (d) => d.id == widget.chatWithId,
                    orElse: () => null);
                final isOnline = userDoc != null ? userDoc['isOnline'] ?? false : false;
                return Text(
                  isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getChatStream(widget.chatWithId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (msg.fileUrl != null)
                                  Image.network(msg.fileUrl!, fit: BoxFit.cover),
                                if (msg.message.isNotEmpty)
                                  Text(
                                    msg.message,
                                    style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.status,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[100],
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _sendMedia,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration.collapsed(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendTextMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
