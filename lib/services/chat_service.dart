import 'dart:typed_data';
import 'dart:convert'; // for base64Encode & jsonDecode
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -----------------------
  // CONNECTION & DEBUG
  // -----------------------
  bool get isConnected => _auth.currentUser != null;

  void debugChats() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }

    print('🔍 Debugging chats for user: ${currentUser.uid}');

    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      print('📊 Found ${snapshot.docs.length} chat documents:');

      if (snapshot.docs.isEmpty) {
        print('📭 No chat documents found in Firestore');
      } else {
        for (var doc in snapshot.docs) {
          print('Chat ID: ${doc.id}');
          print('Data: ${doc.data()}');
          print('---');
        }
      }
    } catch (e) {
      print('❌ Error debugging chats: $e');
    }
  }

  // -----------------------
  // USERS
  // -----------------------
  Stream<QuerySnapshot> getUsersStream() {
    if (!isConnected) return const Stream.empty();

    try {
      return _firestore.collection('users').snapshots();
    } catch (e) {
      print('❌ Error getting users stream: $e');
      return const Stream.empty();
    }
  }

  List<QueryDocumentSnapshot> filterOtherUsers(QuerySnapshot snapshot) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];
    return snapshot.docs.where((doc) => doc.id != currentUser.uid).toList();
  }

  // -----------------------
  // CHAT LIST
  // -----------------------
  Stream<QuerySnapshot> getChatListStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    try {
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots();
    } catch (e) {
      print('❌ Error creating chat list stream: $e');
      return const Stream.empty();
    }
  }

  // -----------------------
  // CHAT MESSAGES
  // -----------------------
  String getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode
        ? '${user1}_$user2'
        : '${user2}_$user1';
  }

  Future<void> sendMessage(String receiverId, String messageText) async {
    if (!isConnected) throw Exception('Not connected to Firebase');

    final currentUser = _auth.currentUser!;
    if (messageText.trim().isEmpty) return;

    final chatId = getChatId(currentUser.uid, receiverId);

    final message = Message(
      id: '',
      senderId: currentUser.uid,
      receiverId: receiverId,
      message: messageText.trim(),
      timestamp: DateTime.now(),
      status: "sent",
    );

    try {
      final batch = _firestore.batch();

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();
      batch.set(messageRef, message.toMap());

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(chatRef, {
        'participants': [currentUser.uid, receiverId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // -----------------------
  // SEND FILE MESSAGE (WEB) via Cloudinary
  // -----------------------
  Future<void> sendFileMessageWeb(
    String receiverId,
    String fileName,
    Uint8List fileBytes,
  ) async {
  final currentUser = _auth.currentUser!;
  final chatId = getChatId(currentUser.uid, receiverId);

  try {
    // Load Cloudinary info from .env
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET'; // create in Cloudinary dashboard
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');

    final base64File = base64Encode(fileBytes);

    final response = await http.post(
      url,
      body: {
        'file': 'data:application/octet-stream;base64,$base64File',
        'upload_preset': uploadPreset,
        'public_id': 'uploads/$fileName',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Cloudinary upload failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final downloadUrl = data['secure_url'];

    // Save message in Firestore
    final message = Message(
      id: '',
      senderId: currentUser.uid,
      receiverId: receiverId,
      message: '',
      fileUrl: downloadUrl,
      timestamp: DateTime.now(),
      status: "sent",
    );

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(messageRef, message.toMap());

    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.set(chatRef, {
      'participants': [currentUser.uid, receiverId],
      'lastMessage': '[File]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': currentUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    print('✅ File message sent successfully via Cloudinary: $fileName');
  } catch (e) {
    print('❌ Error sending file via Cloudinary: $e');
    rethrow;
  }
}
  // -----------------------
  // STREAM MESSAGES
  // -----------------------
  Stream<List<Message>> getChatStream(String receiverId) {
    final currentUser = _auth.currentUser!;
    final chatId = getChatId(currentUser.uid, receiverId);
    return getChatStreamByChatId(chatId);
  }

  Stream<List<Message>> getChatStreamByChatId(String chatId) {
    if (!isConnected) return Stream.value([]);

    try {
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Message.fromMap(doc.data(), doc.id);
            }).toList();
          });
    } catch (e) {
      print('❌ Error creating message stream: $e');
      return Stream.value([]);
    }
  }

  Future<void> markMessageAsSeen(String chatId, String messageId) async {
    if (messageId.trim().isEmpty) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'status': 'seen'});
    } catch (e) {
      print('❌ Error marking message as seen: $e');
    }
  }

  // -----------------------
  // UTILITY METHODS
  // -----------------------
  String getCurrentUserId() => _auth.currentUser?.uid ?? '';

  bool isUserLoggedIn() => _auth.currentUser != null;

  String getCurrentUserDisplayName() {
    return _auth.currentUser?.displayName ??
        _auth.currentUser?.email?.split('@')[0] ??
        'Unknown User';
  }
}
