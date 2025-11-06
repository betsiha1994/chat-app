import 'package:flutter/material.dart';

Icon getMessageStatusIcon(String status) {
  switch (status) {
    case 'sent':
      return const Icon(
        Icons.check,       
        size: 16,
        color: Colors.grey, 
      );
    case 'seen':
      return const Icon(
        Icons.done_all,     
        size: 16,
        color: Colors.blue, 
      );
    default:
      return const Icon(
        Icons.access_time,  
        size: 16,
        color: Colors.grey,
      );
  }
}
