import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class AccountSettingsScreen extends StatefulWidget {
  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  User? user;
  String? profileImage;
  String displayName = '';
  TextEditingController nameController = TextEditingController();
  bool _isEditingName = false;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fetch the user data
  Future<void> _fetchUserData() async {
    user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            profileImage = userDoc['profileImage'] as String? ?? '';
            displayName =
                (userDoc['name'] as String?) ?? user!.email?.substring(0, 5) ?? 'User ';
            nameController.text = displayName; // Set initial value for nameController
          });
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
            'name': user!.email?.substring(0, 5) ?? 'User ',
            'profileImage': '',
          });
          await _fetchUserData();
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _updateProfileImage() async {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      String newImageUrl = await _uploadImage(pickedFile.path);

      if (newImageUrl.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .update({
            'profileImage': newImageUrl,
          });
          setState(() {
            profileImage = newImageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Profile picture updated!'),
          ));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update profile picture. Please try again.'),
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload image. Click to try again.'),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No image selected.'),
      ));
    }
  }

  Future<String> _uploadImage(String imagePath) async {
    try {
      File file = File(imagePath);
      if (!await file.exists()) return '';

      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child('profile_images/$fileName');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return '';
    }
  }

  Future<void> _updateName() async {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String newName = nameController.text.trim();
    if (newName.isNotEmpty) {
      try {
        // Update Firestore document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({
          'name': newName,
        });
        
        setState(() {
          displayName = newName; // Update the displayed name immediately
        });

        // Clear the text field after updating
        nameController.clear();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Name updated successfully!'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating name. Please try again.'),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Name cannot be empty.'),
      ));
    }
  }

  Future<void> _refreshData() async {
    await _fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Settings'),
        backgroundColor: Colors.blue,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurpleAccent,
                Colors.pinkAccent,
                Colors.lightBlueAccent,
                Colors.yellowAccent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _updateProfileImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: profileImage != null && profileImage!.isNotEmpty
                        ? NetworkImage(profileImage!)
                        : null,
                    child: profileImage == null || profileImage!.isEmpty
                        ? Text(
                      user?.email?.isNotEmpty == true
                          ? user!.email![0].toUpperCase()
                          : 'U',
                      style: TextStyle(fontSize: 40, color: Colors.white),
                    )
                        : null,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateProfileImage,
                  child: Text('Change Profile Picture'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'User: ${displayName.isEmpty ? user!.email!.substring(0, 5) : displayName}',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: nameController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    labelText: 'New Name',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.yellow,
                  ),
                  enabled: _isEditingName,
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_isEditingName) {
                      _updateName();
                    } else {
                      setState(() {
                        _isEditingName = true;
                      });
                      _focusNode.requestFocus();
                    }
                  },
                  child: Text(_isEditingName ? 'Save Name' : 'Update Name'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}