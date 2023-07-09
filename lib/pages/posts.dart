import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class FeedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Feed'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              final imageUrl = post['imageUrl'];
              final name = post['name'];
              final image = post['image'];

              final timestamp = post['timestamp']
                  as Timestamp; // Assuming 'timestamp' is a Firestore Timestamp
              final dateTime =
                  timestamp.toDate(); // Convert Firestore Timestamp to DateTime
              final formattedDate = DateFormat.yMMMd()
                  .format(dateTime); // Format the DateTime as desired

              return Padding(
                padding: EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(image),
                      ),
                      title: Text(name),
                      subtitle: Text(formattedDate),
                      onTap: () {
                        // Handle tap on post
                        // You can navigate to a detailed view of the post
                        // and pass the necessary data like imageUrl, user name, etc.
                      },
                    ),
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,

                      ),
                    ),
                    SizedBox(height: 10,),
                    Divider(
                      height: 1,
                      color: Colors.grey,
                      thickness: 0.50,
                      endIndent: 0,
                      indent: 0,
                    ),
                    // SizedBox(height: 10,),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) {
            return PostScreen();
          }));
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class PostScreen extends StatefulWidget {
  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  File? _selectedFile;
  VideoPlayerController? _videoController;
  final picker = ImagePicker();
  bool _isUploading = false;

  // Declare the ImagePicker instance
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageOrVideo() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      // restrict media type to images and videos
      imageQuality: 50, // Adjust image quality as needed
    );

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
        _videoController = VideoPlayerController.file(_selectedFile!);
        _videoController!.initialize().then((_) {
          setState(() {});
        });
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    final storage = FirebaseStorage.instance;
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = storage.ref().child('posts').child(fileName);
    final uploadTask = ref.putFile(_selectedFile!);

    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('posts').add({
      'imageUrl': downloadUrl,
      'timestamp': DateTime.now(),
      'uid': _userId,
      'name': _userName,
      'image': _userImage,
    });

    setState(() {
      _isUploading = false;
      _selectedFile = null;
      _videoController?.dispose();
      _videoController = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File uploaded successfully!')),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String _userName = '';
  String _userImage = '';
  String _userId = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _getCurrentUserData();
  }

  void _getCurrentUserData() async {
    User? user = _auth.currentUser;

    if (user != null) {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(user.uid).get();
      if (userSnapshot.exists) {
        setState(() {
          _userName = userSnapshot.get('nickname');
          _userImage = userSnapshot.get('photoUrl');
          _userId = userSnapshot.get('id');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Post'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedFile != null)
              _videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : Image.file(
                      _selectedFile!,
                      height: 200,
                    )
            else
              Icon(Icons.image, size: 100),
            ElevatedButton(
              onPressed: _pickImageOrVideo,
              child: Text('Choose Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadFile,
              child:
                  _isUploading ? CircularProgressIndicator() : Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
