import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  ChatScreen({required this.friendId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  String? _chatRoomId;
  bool _isOnline = false; // Track online status

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
        _createChatRoom();
        _getFriendStatus();
      });
    }
  }

  void _createChatRoom() {
    if (_currentUserId != null && widget.friendId.isNotEmpty) {
      _chatRoomId = _currentUserId!.compareTo(widget.friendId) > 0
          ? '$_currentUserId-${widget.friendId}'
          : '${widget.friendId}-$_currentUserId';
    }
  }

  Future<void> _getFriendStatus() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.friendId).get();
    setState(() {
      _isOnline = userDoc.data()?['isOnline'] ?? false;
    });
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty && _chatRoomId != null) {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': _currentUserId,
        'receiverId': widget.friendId,
        'message': _messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
      }).then((_) {
        _sendNotification(widget.friendId, _currentUserId!, _messageController.text);
      });

      _messageController.clear();
    }
  }

  Future<void> _sendNotification(String receiverId, String senderId, String message) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
    final token = userDoc.data()?['fcmToken'];

    if (token != null) {
      final payload = {
        'notification': {
          'title': 'New Message',
          'body': '$senderId: $message',
        },
        'to': token,
      };

      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY',
        },
        body: json.encode(payload),
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('hh:mm a').format(timestamp.toDate()); // Format timestamp to hh:mm a
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Friend'),
        backgroundColor: Colors.deepPurple,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatRoomId != null
                ? StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isCurrentUser = message['senderId'] == _currentUserId;

                    return ListTile(
                      title: Align(
                        alignment: isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? Colors.deepPurpleAccent
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['message'],
                                style: TextStyle(
                                  color: isCurrentUser
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              SizedBox(height: 5),
                              if (message['timestamp'] != null)
                                Text(
                                  _formatTimestamp(message['timestamp']),
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
                : Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
