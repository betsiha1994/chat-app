import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../utils/message_status_icon.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../theme.dart'; // Import your theme

class ChatScreen extends StatefulWidget {
  final String chatWith;
  final String chatWithId;

  const ChatScreen({
    super.key,
    required this.chatWith,
    required this.chatWithId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showEmojiPicker = false;

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  // -----------------------
  // SEND TEXT MESSAGE
  // -----------------------
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

  // -----------------------
  // SEND MEDIA
  // -----------------------
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

  // -----------------------
  // MESSAGE OPTIONS
  void _showMessageOptions(Message msg) {
    final isMe = msg.senderId == _chatService.getCurrentUserId();
    if (!isMe) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: primaryColor),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editMessage(Message msg) {
    _messageController.text = msg.message;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: _messageController,
            decoration: const InputDecoration(hintText: 'Edit your message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newText = _messageController.text.trim();
                if (newText.isNotEmpty) {
                  await _chatService.editMessage(
                    _chatService.getChatId(
                      _chatService.getCurrentUserId(),
                      msg.receiverId,
                    ),
                    msg.id,
                    newText,
                  );
                  _messageController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteMessage(Message msg) async {
    await _chatService.deleteMessage(
      _chatService.getChatId(_chatService.getCurrentUserId(), msg.receiverId),
      msg.id,
    );
  }

  // -----------------------
  // BUILD CHAT SCREEN
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final currentUserId = _chatService.getCurrentUserId();

    return Theme(
      data: ThemeData.light().copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.chatWith[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatWith,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  StreamBuilder(
                    stream: _chatService.getUsersStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final userDoc = (snapshot.data as dynamic).docs
                          .firstWhere(
                            (d) => d.id == widget.chatWithId,
                            orElse: () => null,
                          );
                      final isOnline = userDoc != null
                          ? userDoc['isOnline'] ?? false
                          : false;
                      return Text(
                        isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // -----------------------
            // CHAT MESSAGES
            // -----------------------
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chatService.getChatStream(widget.chatWithId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final messages = snapshot.data!;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUserId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 16,
                        ),
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showMessageOptions(msg),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? primaryColor
                                      : messageReceivedColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (msg.fileUrl != null)
                                      Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 100,
                                          maxHeight: 100,
                                        ),
                                        child: Image.network(
                                          msg.fileUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    if (msg.message.isNotEmpty)
                                      Text(
                                        msg.message,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : const Color(0xFF1E1E2D),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white70
                                                : accentColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        isMe
                                            ? getMessageStatusIcon(
                                                msg.status ?? 'sent',
                                              )
                                            : const SizedBox.shrink(),
                                      ],
                                    ),
                                  ],
                                ),
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

            // -----------------------
            // INPUT + EMOJI PICKER
            // -----------------------
            Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 1, color: Colors.grey.shade300),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file, color: accentColor),
                          onPressed: _sendMedia,
                        ),
                        IconButton(
                          icon: Icon(Icons.emoji_emotions, color: accentColor),
                          onPressed: _toggleEmojiPicker,
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Enter Message',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: primaryColor),
                          onPressed: _sendTextMessage,
                        ),
                      ],
                    ),
                  ),

                  // EMOJI PICKER
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 256,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _messageController
                            ..text += emoji.emoji
                            ..selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: _messageController.text.length,
                              ),
                            );
                        },
                        onBackspacePressed: () {
                          if (_messageController.text.isNotEmpty) {
                            _messageController.text = _messageController.text
                                .substring(
                                  0,
                                  _messageController.text.length - 1,
                                );
                          }
                        },
                        textEditingController: _messageController,
                        config: Config(
                          height: 256,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: const EmojiViewConfig(
                            emojiSizeMax: 32,
                          ),
                          categoryViewConfig: const CategoryViewConfig(),
                          skinToneConfig: const SkinToneConfig(),
                          bottomActionBarConfig: const BottomActionBarConfig(),
                          searchViewConfig: const SearchViewConfig(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
