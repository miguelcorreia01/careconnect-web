import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register user and save details to Firestore
  Future<void> registerUserWithDetails({
    required String email,
    required String password,
    required String role,
    required String name,
    required String dob,
    required String phone,
  }) async {
    UserCredential userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCred.user!.uid;

    // Save user profile to /users
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'dob': dob,
      'phone': phone,
      'createdAt': Timestamp.now(),
      'image': 'assets/images/default-profile-picture.png',
    });

    // If role is older_adult, also save to /olderAdults
    if (role == 'older_adult') {
      await _firestore.collection('olderAdults').doc(uid).set({
        'name': name,
        'dob': dob,
        'active': true,
        'createdAt': Timestamp.now(),
      });
    }
  }

  /// Get current user's role
  Future<String?> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['role'];
  }

  /// Optional: logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
