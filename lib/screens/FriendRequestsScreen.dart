import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text('No user logged in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return Center(child: Text('No friend requests'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final senderId = request['senderId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return Container();

                final sender = userSnapshot.data!;
                return ListTile(
                  title: Text("Friend Request from ${sender['name']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => acceptFriendRequest(request.id, senderId, sender['name'], context),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => declineFriendRequest(request.id, context),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Accept Friend Request
  Future<void> acceptFriendRequest(String requestId, String senderId, String senderName, BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Update the friend request status to accepted
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
    });

    // Add sender to current user's friends list
    await FirebaseFirestore.instance.collection('friends').doc(currentUser.uid).set({
      'friendIds': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));

    // Add current user to sender's friends list
    await FirebaseFirestore.instance.collection('friends').doc(senderId).set({
      'friendIds': FieldValue.arrayUnion([currentUser.uid]),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("You are now friends with ${senderName}"),
    ));
  }

  // Decline Friend Request
  Future<void> declineFriendRequest(String requestId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Friend request declined"),
    ));
  }
}
