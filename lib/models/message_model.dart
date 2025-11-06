import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String? fileUrl; 
  final String? fileType; 
  final DateTime timestamp;
  final String status; 

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.fileUrl,
    this.fileType,
    required this.timestamp,
    this.status = "sent",
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'timestamp': Timestamp.fromDate(
        timestamp,
      ), 
      'status': status,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    DateTime timestamp;

    if (map['timestamp'] is Timestamp) {
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      timestamp = DateTime.parse(map['timestamp']);
    } else {
      timestamp = DateTime.now();
    }

    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      fileUrl: map['fileUrl'],
      timestamp: timestamp,
      status: map['status'] ?? "sent",
    );
  }
}
