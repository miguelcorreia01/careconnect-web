import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageCaregiversScreen extends StatefulWidget {
  const ManageCaregiversScreen({super.key});

  @override
  State<ManageCaregiversScreen> createState() => _ManageCaregiversScreenState();
}

class _ManageCaregiversScreenState extends State<ManageCaregiversScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> caregivers = [];
  String searchQuery = '';
  String roleFilter = 'all'; // 'all', 'caregiver', 'family'

  @override
  void initState() {
    super.initState();
    fetchCaregivers();
  }

  Future<void> fetchCaregivers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final relationSnapshot = await FirebaseFirestore.instance
        .collection('caregiver_patients')
        .where('patient_id', isEqualTo: currentUser.uid)
        .get();

    final caregiverIds = relationSnapshot.docs.map((doc) => doc['caregiver_id']).toList();

    if (caregiverIds.isEmpty) {
      setState(() => caregivers = []);
      return;
    }

    Query usersQuery = FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: caregiverIds);

    if (roleFilter == 'caregiver' || roleFilter == 'family') {
      usersQuery = usersQuery.where('role', isEqualTo: roleFilter);
    }

    final userSnapshot = await usersQuery.get();

    setState(() {
      caregivers = userSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Usa profileImage se existir, senão image
        final profileImage = (data['profileImage'] ?? '').toString();
        final image = (profileImage.isNotEmpty)
            ? profileImage
            : (data['image'] ?? 'assets/images/default-profile-picture.png').toString();
        return {
          'name': data['name'] ?? 'Unknown',
          'role': data['role'] ?? '',
          'image': image,
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
          'uid': doc.id,
        };
      }).toList();
    });
  }

  void addCaregiverDialog() {
    final TextEditingController emailController = TextEditingController();
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              backgroundColor: const Color(0xFFF7FAFC),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.group_add, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Add Caregiver or Family',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2F8369)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the email of the caregiver or family member you want to add to your care list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        style: const TextStyle(fontSize: 20),
                        decoration: InputDecoration(
                          labelText: 'Caregiver/Family Email',
                          labelStyle: const TextStyle(fontSize: 18, color: Colors.black87),
                          prefixIcon: const Icon(Icons.email, color: Color(0xFF2F8369)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                          errorText: errorText,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (errorText != null) setModalState(() => errorText = null);
                        },
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.cancel, color: Colors.black54),
                            label: const Text('Cancel', style: TextStyle(fontSize: 18, color: Colors.black)),
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle, color: Colors.white),
                            label: const Text('Link', style: TextStyle(fontSize: 20, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F8369),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final email = emailController.text.trim();
                                    if (email.isEmpty) {
                                      setModalState(() => errorText = 'Please enter an email.');
                                      return;
                                    }
                                    if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+").hasMatch(email)) {
                                      setModalState(() => errorText = 'Enter a valid email.');
                                      return;
                                    }
                                    setModalState(() => isLoading = true);

                                    final result = await FirebaseFirestore.instance
                                        .collection('users')
                                        .where('email', isEqualTo: email)
                                        .limit(1)
                                        .get();

                                    if (result.docs.isEmpty ||
                                        !(result.docs.first['role'] == 'caregiver' || result.docs.first['role'] == 'family')) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorText = 'Caregiver or family member not found.';
                                      });
                                      return;
                                    }

                                    final caregiverId = result.docs.first.id;
                                    final patientId = _auth.currentUser!.uid;

                                    // Verificar se já está associado
                                    final existingRelation = await FirebaseFirestore.instance
                                        .collection('caregiver_patients')
                                        .where('caregiver_id', isEqualTo: caregiverId)
                                        .where('patient_id', isEqualTo: patientId)
                                        .limit(1)
                                        .get();

                                    if (existingRelation.docs.isNotEmpty) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorText = 'This user is already linked to you.';
                                      });
                                      return;
                                    }

                                    if (caregivers.any((c) => c['uid'] == caregiverId)) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorText = 'This user is already linked to you.';
                                      });
                                      return;
                                    }

                                    await FirebaseFirestore.instance.collection('caregiver_patients').add({
                                      'caregiver_id': caregiverId,
                                      'patient_id': patientId,
                                    });

                                    setModalState(() => isLoading = false);
                                    Navigator.of(context).pop();
                                    fetchCaregivers();
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRemoveCaregiver(String name, String uid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  Text('Remove $name?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to remove this caregiver/family member? You will no longer have access to their information.',
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.black54),
                        label: const Text('Cancel', style: TextStyle(color: Colors.black)),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text('Remove', style: TextStyle(fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final patientId = _auth.currentUser!.uid;
                          final snapshot = await FirebaseFirestore.instance
                              .collection('caregiver_patients')
                              .where('caregiver_id', isEqualTo: uid)
                              .where('patient_id', isEqualTo: patientId)
                              .get();
                          for (var doc in snapshot.docs) {
                            await doc.reference.delete();
                          }
                          Navigator.of(context).pop();
                          fetchCaregivers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name has been removed.')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCaregivers = caregivers.where((c) =>
      c['name'].toLowerCase().contains(searchQuery.toLowerCase()) &&
      (roleFilter == 'all' || c['role'] == roleFilter)
    ).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFD9D9D9),
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(text: 'Care', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                  TextSpan(text: 'Connect', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/old_adult_dashboard'),
              child: Text(
                'Dashboard',
                style: TextStyle(
                  color: ModalRoute.of(context)?.settings.name == '/old_adult_dashboard'
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {},
              child: Text(
                'Caregivers',
                style: TextStyle(
                  color: ModalRoute.of(context)?.settings.name == '/manage_caregivers'
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
            onPressed: () {},
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
                              content: Text('Emergency activated! Help is on the way.'),
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
              Navigator.pushNamed(context, '/profile');
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caregivers & Family Members', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You currently have ${caregivers.length} caregivers/family members',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => searchQuery = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: roleFilter,
                  onChanged: (value) {
                    setState(() {
                      roleFilter = value!;
                    });
                    fetchCaregivers();
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.people, color: Colors.green),
                          SizedBox(width: 6),
                          Text('All'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'caregiver',
                      child: Row(
                        children: [
                          Icon(Icons.medical_services, color: Colors.blue),
                          SizedBox(width: 6),
                          Text('Caregivers'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'family',
                      child: Row(
                        children: [
                          Icon(Icons.family_restroom, color: Colors.orange),
                          SizedBox(width: 6),
                          Text('Family'),
                        ],
                      ),
                    ),
                  ],
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  underline: Container(height: 2, color: Colors.green),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: addCaregiverDialog,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    label: const Text('Add Caregiver', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 48),
                      maximumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 800 ? 5 : constraints.maxWidth > 600 ? 3 : 2;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredCaregivers.length,
                    itemBuilder: (context, index) {
                      final person = filteredCaregivers[index];
                      return Card(
                        color: const Color(0xFFF7FAFC),
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 60,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                child: (person['image'] != null && person['image'].toString().startsWith('http'))
                                    ? Image.network(
                                        person['image'],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Image.asset('assets/images/default-profile-picture.png', fit: BoxFit.cover),
                                      )
                                    : Image.asset(
                                        person['image'] ?? 'assets/images/default-profile-picture.png',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Container(
                              height: 2,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 20, color: Colors.blueGrey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          person['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 17,
                                            letterSpacing: 0.2,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.badge, size: 18, color: Colors.green),
                                      const SizedBox(width: 6),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Role: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.black54,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                            TextSpan(
                                              text: person['role'].isNotEmpty
                                                  ? person['role'][0].toUpperCase() + person['role'].substring(1)
                                                  : '',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black54,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 18, color: Colors.blue),
                                      const SizedBox(width: 6),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Phone: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.black54,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                            TextSpan(
                                              text: person['phone'].toString().isNotEmpty
                                                  ? person['phone'].toString()
                                                  : '-',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black54,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.email, size: 18, color: Colors.deepPurple),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Email: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.black54,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                              TextSpan(
                                                text: person['email'].toString().isNotEmpty
                                                    ? person['email'].toString()
                                                    : '-',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.black54,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _confirmRemoveCaregiver(person['name'], person['uid']),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                          child: const Text('Remove'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}
