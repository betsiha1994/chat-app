import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String? fileUrl; // nullable
  final String? fileType; // nullable
  final DateTime timestamp;
  final String status; // "sent", "seen"

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

  // Convert to Map for Firestore (using Timestamp)
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'timestamp': Timestamp.fromDate(
        timestamp,
      ), // Convert DateTime to Firestore Timestamp
      'status': status,
    };
  }

  // Convert from Firestore Map (handling Timestamp)
  factory Message.fromMap(Map<String, dynamic> map, String id) {
    // Handle both Timestamp and DateTime formats
    DateTime timestamp;

    if (map['timestamp'] is Timestamp) {
      // If it's a Firestore Timestamp
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      // If it's stored as string (backward compatibility)
      timestamp = DateTime.parse(map['timestamp']);
    } else {
      // Fallback to current time
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
