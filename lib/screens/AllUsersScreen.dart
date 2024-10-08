import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllUsersScreen extends StatelessWidget {
  final String currentUserId;

  AllUsersScreen({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Users'),
      ),
      body: Column(
        children: [
          _buildCurrentUserInfo(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                print('Snapshot data: ${snapshot.data}');
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs.where((doc) {
                  return doc.id != currentUserId;
                }).toList();

                print('Users list: $users');

                if (users.isEmpty) {
                  return Center(child: Text('No other users found'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userData = user.data() as Map<String, dynamic>;
                    final userName = userData['name'] ?? userData['displayName'] ?? 'Unnamed User';
                    final profileImage = userData['photoURL'] ?? 'https://via.placeholder.com/150';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(profileImage),
                        child: profileImage.isEmpty
                            ? Text(userName[0].toUpperCase())
                            : null,
                      ),
                      title: Text(userName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.person_add),
                            onPressed: () => sendFriendRequest(user.id, context),
                          ),
                          IconButton(
                            icon: Icon(Icons.person_remove),
                            onPressed: () => removeFriend(user.id, context),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCurrentUserInfo() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Container();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final currentUserName = userData['name'] ?? userData['displayName'] ?? 'Unnamed User';
        final currentUserImage = userData['photoURL'] ?? 'https://via.placeholder.com/150';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(currentUserImage),
            child: currentUserImage.isEmpty
                ? Text(currentUserName[0].toUpperCase())
                : null,
          ),
          title: Text(currentUserName),
          subtitle: Text('You'),
        );
      },
    );
  }

  Future<void> sendFriendRequest(String receiverId, BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Check if a friend request already exists
      final existingRequest = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: receiverId)
          .get();

      // Check if they are already friends
      final friendCheck = await FirebaseFirestore.instance
          .collection('friends')
          .doc(currentUser.uid)
          .get();

      final isFriend = friendCheck.exists &&
          (friendCheck.data()!['friendIds'] as List<dynamic>).contains(receiverId);

      if (existingRequest.docs.isEmpty && !isFriend) {
        // Send a new friend request
        await FirebaseFirestore.instance.collection('friend_requests').add({
          'senderId': currentUser.uid,
          'receiverId': receiverId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend request sent')));
      } else if (existingRequest.docs.isNotEmpty) {
        // Here we log the details of existing requests for debugging
        print('Existing request: ${existingRequest.docs.map((doc) => doc.data())}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend request already exists')));
      } else if (isFriend) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You are already friends')));
      }
    }
  }

  Future<void> removeFriend(String friendId, BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Remove from friends collection
      await FirebaseFirestore.instance.collection('friends').doc(currentUser.uid).update({
        'friendIds': FieldValue.arrayRemove([friendId]),
      });

      final existingRequest = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: friendId)
          .where('receiverId', isEqualTo: currentUser.uid)
          .get();

      for (var request in existingRequest.docs) {
        await request.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend removed')));
    }
  }
}
