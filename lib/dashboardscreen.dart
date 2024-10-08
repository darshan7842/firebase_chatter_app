import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_chatter_app/screens/AccountSettingsScreen.dart';
import 'package:firebase_chatter_app/screens/AllUsersScreen.dart';
import 'package:firebase_chatter_app/screens/ChatScreen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Loginscreen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? name;
  String? profileImage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          name = userDoc['name'] ?? 'No name available';
          profileImage = userDoc['photoURL'] ?? 'default_image_url';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Let\'s Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            color: Colors.white,
            onPressed: _showActionMenu,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            color: Colors.white,
            onPressed: _logout,
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Colors.deepPurple,
              child: TabBar(
                tabs: [
                  Tab(text: 'REQUESTS'),
                  Tab(text: 'CHATS'),
                  Tab(text: 'FRIENDS'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.white,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFriendRequests(),
                  _buildChatList(),
                  _buildFriendsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 200,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Account Settings'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(AccountSettingsScreen());
                },
              ),
              ListTile(
                leading: Icon(Icons.people),
                title: Text('View All Users'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(AllUsersScreen(
                      currentUserId: FirebaseAuth.instance.currentUser?.uid ?? ''));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateTo(Widget screen) {
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _logout() async {
    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Clear any local user state (like shared preferences)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Widget _buildFriendRequests() {
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
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

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

                if (!userSnapshot.data!.exists) {
                  return ListTile(
                    title: Text('Friend data not available'),
                  );
                }

                final sender = userSnapshot.data!.data() as Map<String, dynamic>?;

                if (sender == null) {
                  return ListTile(
                    title: Text('Friend data not available'),
                  );
                }

                final friendEmail = sender['email'] ?? '';
                final friendName = friendEmail.length > 5
                    ? friendEmail.substring(0, 5)
                    : friendEmail;

                return ListTile(
                  title: Text("Friend Request from $friendName"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        child: Text('Accept', style: TextStyle(color: Colors.green)),
                        onPressed: () => acceptFriendRequest(request.id, senderId),
                      ),
                      TextButton(
                        child: Text('Decline', style: TextStyle(color: Colors.red)),
                        onPressed: () => declineFriendRequest(request.id),
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

  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'accepted'});

    await FirebaseFirestore.instance.collection('friends').doc(currentUser.uid).set({
      'friendIds': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('friends').doc(senderId).set({
      'friendIds': FieldValue.arrayUnion([currentUser.uid]),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You are now friends with $senderId")),
    );

    _navigateToChat(senderId);
  }

  Future<void> declineFriendRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Friend request declined")),
    );
  }

  Widget _buildChatList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text('No user logged in'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('friends').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final friendsData = snapshot.data!.data() as Map<String, dynamic>?;

        if (friendsData == null || !friendsData.containsKey('friendIds')) {
          return Center(child: Text('No friends found'));
        }

        final friendIds = friendsData['friendIds'] as List<dynamic>;

        return ListView.builder(
          itemCount: friendIds.length,
          itemBuilder: (context, index) {
            final friendId = friendIds[index];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return Container();

                if (!userSnapshot.data!.exists) {
                  return ListTile(
                    title: Text('Friend data not available'),
                  );
                }

                final friend = userSnapshot.data!.data() as Map<String, dynamic>?;

                if (friend == null) {
                  return ListTile(
                    title: Text('Friend data not available'),
                  );
                }

                final friendName = friend['name'] ?? 'Unknown';
                final friendPhotoURL = friend['photoURL'] ?? '';

                return ListTile(
                  leading: friendPhotoURL.isNotEmpty
                      ? CircleAvatar(
                    backgroundImage: NetworkImage(friendPhotoURL),
                  )
                      : CircleAvatar(child: Text(friendName[0])),
                  title: Text(friendName),
                  onTap: () => _navigateToChat(friendId),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text('No user logged in'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('friends').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final friendsData = snapshot.data!.data() as Map<String, dynamic>?;

        if (friendsData == null || !friendsData.containsKey('friendIds')) {
          return Center(child: Text('No friends found'));
        }

        final friendIds = friendsData['friendIds'] as List<dynamic>;

        return ListView.builder(
          itemCount: friendIds.length,
          itemBuilder: (context, index) {
            final friendId = friendIds[index];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return Container();

                if (!userSnapshot.data!.exists) {
                  return ListTile(
                    title: Text('Friend data not available'),
                  );
                }

                final friend = userSnapshot.data!.data() as Map<String, dynamic>?;

                if (friend == null) {
                  return ListTile(
                    title: Text('Friend data not available'),
                  );
                }

                final friendName = friend['name'] ?? 'Unknown';
                final friendPhotoURL = friend['photoURL'] ?? '';

                return ListTile(
                  leading: friendPhotoURL.isNotEmpty
                      ? CircleAvatar(
                    backgroundImage: NetworkImage(friendPhotoURL),
                  )
                      : CircleAvatar(child: Text(friendName[0])),
                  title: Text(friendName),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeFriend(friendId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _removeFriend(String friendId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection('friends').doc(currentUser.uid).update({
      'friendIds': FieldValue.arrayRemove([friendId]),
    });

    await FirebaseFirestore.instance.collection('friends').doc(friendId).update({
      'friendIds': FieldValue.arrayRemove([currentUser.uid]),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Friend removed successfully")),
    );
  }

  void _navigateToChat(String friendId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(friendId: friendId)),
    );
  }
}
