import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:badges/badges.dart' as badges;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _role;
  String? _countryCode = '+351';
  bool _loading = true;
  String? _profileImageUrl;
  bool _uploadingImage = false; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      // Fetch additional user data from Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _dobController.text = data['dob'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _role = data['role'] ?? '';
        _countryCode = data['countryCode'] ?? '+351';
        _profileImageUrl = data['profileImage'] as String?;
      }
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _updateUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'name': _nameController.text,
          'address': _addressController.text,
          'dob': _dobController.text,
          'phone': _phoneController.text,
          'countryCode': _countryCode, // Ensure prefix is saved
        },
      );
    }
  }

  Future<void> uploadProfileImageWebSafe(
    Function(String) onImageUpdated,
  ) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    try {
      // Read file bytes safely on web
      final bytes = await pickedImage.readAsBytes();

      // Create storage reference
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_images/$uid.jpg',
      );

      // Upload as binary data
      await storageRef.putData(bytes);

      // Get download URL
      final imageUrl = await storageRef.getDownloadURL();

      // Save image URL to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImage': imageUrl,
      });

      // Trigger UI update or callback
      onImageUpdated(imageUrl);
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  // Helper to capitalize each word, preserving underscores as spaces
  String _capitalizeWords(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) =>
              w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                  : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String? role = _role?.toLowerCase();

    // --- HEADER FOR ADMIN (copied from admin_dashboard.dart) ---
    if (role == 'admin') {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFD9D9D9),
          title: Row(
            children: [
              const Text(
                'Care',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                'Connect',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin_dashboard');
                },
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color:
                        ModalRoute.of(context)?.settings.name ==
                                '/admin_dashboard'
                            ? Colors.blue
                            : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/users_list');
                },
                child: Text(
                  'Users List',
                  style: TextStyle(
                    color:
                        ModalRoute.of(context)?.settings.name == '/users_list'
                            ? Colors.blue
                            : Colors.black,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.black),
              onPressed: () {
                // Already in profile
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/home_screen');
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Center(
            child:
                isWideScreen
                    ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildProfileCard()),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _buildUserDataCard(),
                                const SizedBox(height: 16),
                                _buildPasswordCard(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildUserDataCard(),
                        const SizedBox(height: 16),
                        _buildPasswordCard(),
                      ],
                    ),
          ),
        ),
      );
    }
    // --- END HEADER FOR ADMIN ---

    // --- HEADER FOR OLDER ADULT (copied from old_adult_dashboard.dart) ---
    if (role == 'older_adult') {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFD9D9D9),
          title: Row(
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Care',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    TextSpan(
                      text: 'Connect',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/old_adult_dashboard');
                },
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color:
                        ModalRoute.of(context)?.settings.name ==
                                '/old_adult_dashboard'
                            ? Colors.blue
                            : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/manage_caregivers');
                },
                child: Text(
                  'Caregivers',
                  style: TextStyle(
                    color:
                        ModalRoute.of(context)?.settings.name ==
                                '/caregiver_dashboard'
                            ? Colors.blue
                            : Colors.black,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                // Handle notifications
              },
            ),
            IconButton(
              icon: const Icon(Icons.emergency, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Column(
                        children: [
                          Icon(Icons.emergency, size: 48, color: Colors.red),
                          const SizedBox(height: 8),
                          const Text(
                            'Activate Emergency',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      content: const Text(
                        'Are you sure you want to activate the emergency button?',
                        textAlign: TextAlign.center,
                      ),
                      actionsAlignment: MainAxisAlignment.spaceEvenly,
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.grey.shade300,
                          ),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Emergency activated! Help is on the way.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Activate'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.black),
              onPressed: () {
                // Already in profile, do nothing or maybe Navigator.pushNamed(context, '/profile');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/home_screen');
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Center(
            child:
                isWideScreen
                    ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildProfileCard()),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _buildUserDataCard(),
                                const SizedBox(height: 16),
                                _buildPasswordCard(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildUserDataCard(),
                        const SizedBox(height: 16),
                        _buildPasswordCard(),
                      ],
                    ),
          ),
        ),
      );
    }
    // --- END HEADER FOR OLDER ADULT ---

    // --- HEADER FOR FAMILY (copied from family_dashboard.dart) ---
    if (role == 'family') {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFD9D9D9),
          title: Row(
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Care',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    TextSpan(
                      text: 'Connect',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/family_dashboard');
                },
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color: ModalRoute.of(context)?.settings.name == '/family_dashboard'
                        ? Colors.blue
                        : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/manage_patients_family');
                },
                child: Text(
                  'Family Members',
                  style: TextStyle(
                    color: ModalRoute.of(context)?.settings.name == '/manage_patients_family'
                        ? Colors.blue
                        : Colors.black,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          actions: [
            // Removed: IconButton(
            //   icon: const Icon(Icons.notifications, color: Colors.black),
            //   onPressed: () {
            //     // Handle notifications
            //   },
            // ),
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.black),
              onPressed: () {
                // Already in profile, do nothing or maybe Navigator.pushNamed(context, '/profile');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/home_screen');
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Center(
            child:
                isWideScreen
                    ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildProfileCard()),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _buildUserDataCard(),
                                const SizedBox(height: 16),
                                _buildPasswordCard(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildUserDataCard(),
                        const SizedBox(height: 16),
                        _buildPasswordCard(),
                      ],
                    ),
          ),
        ),
      );
    }
    // --- END HEADER FOR FAMILY ---

    // --- HEADER FOR CAREGIVER (copied from caregiver_dashboard.dart) ---
    if (role == 'caregiver') {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFD9D9D9),
          title: Row(
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Care',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    TextSpan(
                      text: 'Connect',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/caregiver_dashboard');
                    },
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        color:
                            ModalRoute.of(context)?.settings.name ==
                                    '/caregiver_dashboard'
                                ? Colors.blue
                                : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/patients');
                    },
                    child: Text(
                      'Patients',
                      style: TextStyle(
                        color:
                            ModalRoute.of(context)?.settings.name == '/patients'
                                ? Colors.blue
                                : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                // Handle notifications
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.black),
              onPressed: () {
                // Already in profile, do nothing or maybe Navigator.pushNamed(context, '/profile');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/home_screen');
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Center(
            child:
                isWideScreen
                    ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildProfileCard()),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _buildUserDataCard(),
                                const SizedBox(height: 16),
                                _buildPasswordCard(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildUserDataCard(),
                        const SizedBox(height: 16),
                        _buildPasswordCard(),
                      ],
                    ),
          ),
        ),
      );
    }
    // --- END HEADER FOR CAREGIVER ---

    // ...existing code for other roles...
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9D9D9),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              'Care',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Text(
              'Connect',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Spacer(),
            // ...existing code for headerButtons...
            const Spacer(),
            GestureDetector(
              onTapDown: (TapDownDetails details) {
                final RenderBox renderBox =
                    context.findRenderObject() as RenderBox;
                final Offset offset = renderBox.localToGlobal(Offset.zero);
                showMenu(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    offset.dx + renderBox.size.width - 40,
                    offset.dy + 56,
                    offset.dx,
                    offset.dy,
                  ),
                  items: [
                    PopupMenuItem(
                      child: ListTile(
                        leading: const Icon(Icons.event, color: Colors.blue),
                        title: const Text('Your appointment is tomorrow.'),
                      ),
                    ),
                    PopupMenuItem(
                      child: ListTile(
                        leading: const Icon(Icons.update, color: Colors.green),
                        title: const Text(
                          'Your profile was updated successfully.',
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: badges.Badge(
                badgeContent: const Text(
                  '1',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                position: badges.BadgePosition.topEnd(top: -5, end: -5),
                child: const Icon(Icons.notifications, color: Colors.black),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.black),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/home_screen',
                ); // Navigate to the main screen
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          48,
          24,
          24,
        ), // Added top margin of 48
        child: Center(
          child:
              isWideScreen
                  ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildProfileCard()),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              _buildUserDataCard(),
                              const SizedBox(height: 16),
                              _buildPasswordCard(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 24),
                      _buildUserDataCard(),
                      const SizedBox(height: 16),
                      _buildPasswordCard(),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final imageProvider =
        (_profileImageUrl != null &&
                _profileImageUrl!.isNotEmpty &&
                !_profileImageUrl!.startsWith('assets/'))
            ? NetworkImage(_profileImageUrl!)
            : const AssetImage('assets/images/default-profile-image.png')
                as ImageProvider;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile image with edit overlay
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: imageProvider,
                  backgroundColor: Colors.grey[200],
                  child: _uploadingImage
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 4,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        setState(() {
                          _uploadingImage = true;
                        });
                        await uploadProfileImageWebSafe((updatedUrl) {
                          setState(() {
                            _profileImageUrl = updatedUrl;
                            _uploadingImage = false;
                          });
                        });
                        setState(() {
                          _uploadingImage = false;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              _nameController.text,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _emailController.text,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _role == 'admin'
                        ? Icons.admin_panel_settings
                        : _role == 'caregiver'
                        ? Icons.health_and_safety
                        : _role == 'family'
                        ? Icons.family_restroom
                        : _role == 'older_adult'
                        ? Icons.elderly
                        : Icons.person_outline,
                    color: Colors.indigo,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _capitalizeWords(_role),
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Divider(color: Colors.grey[300], thickness: 1, height: 1),
            const SizedBox(height: 24),
            // Improved button layout: more space and clear separation
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/home_screen');
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          final confirmController = TextEditingController();
                          String? errorText;
                          bool isDeleting = false;
                          // FIX: Return the Dialog directly, not inside a StatefulBuilder
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: StatefulBuilder(
                                  builder:
                                      (context, setState) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            size: 56,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Delete Account',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 22,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'To confirm, please type:\n"I want to delete my account"',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 18),
                                          TextField(
                                            controller: confirmController,
                                            decoration: InputDecoration(
                                              border:
                                                  const OutlineInputBorder(),
                                              labelText: 'Confirmation text',
                                              errorText: errorText,
                                            ),
                                            onChanged: (_) {
                                              if (errorText != null) {
                                                setState(
                                                  () => errorText = null,
                                                );
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              TextButton.icon(
                                                icon: const Icon(
                                                  Icons.cancel,
                                                  color: Colors.black54,
                                                ),
                                                label: const Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                onPressed:
                                                    () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                style: TextButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                icon:
                                                    isDeleting
                                                        ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                        )
                                                        : const Icon(
                                                          Icons.delete_forever,
                                                          color: Colors.white,
                                                        ),
                                                label: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 28,
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                onPressed:
                                                    isDeleting
                                                        ? null
                                                        : () async {
                                                          if (confirmController
                                                                  .text
                                                                  .trim() !=
                                                              "I want to delete my account") {
                                                            setState(
                                                              () =>
                                                                  errorText =
                                                                      'Text does not match.',
                                                            );
                                                            return;
                                                          }
                                                          setState(
                                                            () =>
                                                                isDeleting =
                                                                    true,
                                                          );
                                                          final user =
                                                              FirebaseAuth
                                                                  .instance
                                                                  .currentUser;
                                                          if (user != null) {
                                                            await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                  'users',
                                                                )
                                                                .doc(user.uid)
                                                                .delete();
                                                            await user.delete();
                                                          }
                                                          if (context.mounted) {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            Navigator.pushNamed(
                                                              context,
                                                              '/home_screen',
                                                            );
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Account deleted successfully.',
                                                                ),
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting your account is permanent.',
              style: TextStyle(color: Colors.red[300], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDataCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField('Name', Icons.person, _nameController),
            const SizedBox(height: 16),
            _buildTextField('Address', Icons.home, _addressController),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildPhoneField(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await _updateUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User data updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Update User Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[100],
                foregroundColor: Colors.teal[900],
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    String? errorMessage;
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: oldPasswordController,
                  obscureText: !showOldPassword,
                  decoration: InputDecoration(
                    labelText: 'Old Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showOldPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => showOldPassword = !showOldPassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => showNewPassword = !showNewPassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        );
                      },
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            setState(() {
                              errorMessage = null;
                              isLoading = true;
                            });
                            final oldPassword =
                                oldPasswordController.text.trim();
                            final newPassword =
                                newPasswordController.text.trim();
                            final confirmPassword =
                                confirmPasswordController.text.trim();

                            if (oldPassword.isEmpty ||
                                newPassword.isEmpty ||
                                confirmPassword.isEmpty) {
                              setState(() {
                                errorMessage = 'All fields are required.';
                                isLoading = false;
                              });
                              return;
                            }
                            if (newPassword != confirmPassword) {
                              setState(() {
                                errorMessage = 'New passwords do not match.';
                                isLoading = false;
                              });
                              return;
                            }
                            if (newPassword.length < 6) {
                              setState(() {
                                errorMessage =
                                    'New password must be at least 6 characters.';
                                isLoading = false;
                              });
                              return;
                            }
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null)
                                throw Exception('User not found');
                              final cred = EmailAuthProvider.credential(
                                email: user.email!,
                                password: oldPassword,
                              );
                              await user.reauthenticateWithCredential(cred);
                              await user.updatePassword(newPassword);
                              setState(() {
                                isLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password changed successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              oldPasswordController.clear();
                              newPasswordController.clear();
                              confirmPasswordController.clear();
                            } on FirebaseAuthException catch (e) {
                              setState(() {
                                errorMessage =
                                    e.code == 'wrong-password'
                                        ? 'Old password is incorrect.'
                                        : (e.message ??
                                            'Failed to change password.');
                                isLoading = false;
                              });
                            } catch (e) {
                              setState(() {
                                errorMessage = 'Failed to change password.';
                                isLoading = false;
                              });
                            }
                          },
                  icon:
                      isLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal,
                            ),
                          )
                          : const Icon(Icons.password),
                  label: const Text('Change Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[100],
                    foregroundColor: Colors.teal[900],
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ],
            ),
        ));
      },
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDateField() {
    return TextField(
      controller: _dobController,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Date of Birth',
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate:
              DateTime.tryParse(
                _dobController.text.split('/').reversed.join('-'),
              ) ??
              DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          _dobController.text =
              "${picked.day.toString().padLeft(2, '0')}/"
              "${picked.month.toString().padLeft(2, '0')}/"
              "${picked.year}";
        }
      },
    );
  }

  Widget _buildPhoneField() {
    return Row(
      children: [
        CountryCodePicker(
          onChanged: (country) {
            setState(() {
              _countryCode = country.dialCode;
            });
          },
          initialSelection: _countryCode ?? 'PT',
          favorite: const ['+351', 'PT'],
          showFlag: true,
          showCountryOnly: false,
          showOnlyCountryWhenClosed: false,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
            // Remove any prefix from the input box if present
            onChanged: (val) {
              if (_countryCode != null && val.startsWith(_countryCode!)) {
                final clean = val.replaceFirst(_countryCode!, '').trimLeft();
                _phoneController.value = TextEditingValue(
                  text: clean,
                  selection: TextSelection.collapsed(offset: clean.length),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
