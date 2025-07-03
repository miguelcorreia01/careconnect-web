import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManagePatientsFamilyScreen extends StatefulWidget {
  const ManagePatientsFamilyScreen({super.key});

  @override
  State<ManagePatientsFamilyScreen> createState() => _ManagePatientsFamilyScreenState();
}

class _ManagePatientsFamilyScreenState extends State<ManagePatientsFamilyScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> patients = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchPatients();
  }

  Future<void> fetchPatients() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // family_patients: { family_id, patient_id }
    final relationSnapshot = await FirebaseFirestore.instance
        .collection('family_patients')
        .where('family_id', isEqualTo: currentUser.uid)
        .get();

    final patientIds = relationSnapshot.docs.map((doc) => doc['patient_id']).toList();

    if (patientIds.isEmpty) {
      setState(() => patients = []);
      return;
    }

    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: patientIds)
        .get();

    setState(() {
      patients = userSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? 'Unknown',
          'age': _calculateAge(data['dob']),
          'image': (data['profileImage'] ?? data['image'] ?? '').toString(),
          'phone': data['phone'] ?? '',
          'uid': doc.id,
        };
      }).toList();
    });
  }

  int _calculateAge(String dob) {
    try {
      final parts = dob.split('/');
      final birthDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }

  void addPatientDialog() {
    final TextEditingController emailController = TextEditingController();
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add Older Adult',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the email of the older adult you want to add to your family list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Older Adult Email',
                          prefixIcon: const Icon(Icons.email),
                          border: const OutlineInputBorder(),
                          errorText: errorText,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (errorText != null) setModalState(() => errorText = null);
                        },
                      ),
                      const SizedBox(height: 18),
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
                            icon: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check, color: Colors.white),
                            label: const Text('Link', style: TextStyle(fontSize: 16, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

                                    if (result.docs.isEmpty || result.docs.first['role'] != 'older_adult') {
                                      setModalState(() {
                                        isLoading = false;
                                        errorText = 'Older adult not found.';
                                      });
                                      return;
                                    }

                                    final userId = result.docs.first.id;
                                    final familyId = _auth.currentUser!.uid;

                                    final existingRelation = await FirebaseFirestore.instance
                                        .collection('family_patients')
                                        .where('family_id', isEqualTo: familyId)
                                        .where('patient_id', isEqualTo: userId)
                                        .limit(1)
                                        .get();

                                    if (existingRelation.docs.isNotEmpty) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorText = 'This older adult is already linked to you.';
                                      });
                                      return;
                                    }

                                    await FirebaseFirestore.instance
                                        .collection('family_patients')
                                        .add({
                                          'family_id': familyId,
                                          'patient_id': userId,
                                        });

                                    setModalState(() => isLoading = false);
                                    Navigator.of(context).pop();
                                    fetchPatients();
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

  void _confirmRemovePatient(String name, String uid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Remove $name?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to remove this patient from your family list? You will no longer have access to their information.',
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
                          final familyId = _auth.currentUser!.uid;
                          final snapshot = await FirebaseFirestore.instance
                              .collection('family_patients')
                              .where('family_id', isEqualTo: familyId)
                              .where('patient_id', isEqualTo: uid)
                              .get();
                          for (var doc in snapshot.docs) {
                            await doc.reference.delete();
                          }
                          Navigator.of(context).pop();
                          fetchPatients();
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
    final filteredPatients = patients.where(
      (p) => p['name'].toLowerCase().contains(searchQuery.toLowerCase()),
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
                  TextSpan(
                    text: 'Care',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  TextSpan(
                    text: 'Connect',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/family_dashboard'),
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
              onPressed: () {},
              child: const Text(
                'Family Members',
                style: TextStyle(
                  color: Colors.blue,
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
            const Text(
              'Old Adults Under My Care',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You are currently managing ${patients.length} seniors',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
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
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: addPatientDialog,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    label: const Text('Add Patient', style: TextStyle(color: Colors.white)),
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
                    itemCount: filteredPatients.length,
                    itemBuilder: (context, index) {
                      final person = filteredPatients[index];
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
                                child: person['image'].toString().startsWith('http')
                                    ? Image.network(
                                        person['image'],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Image.asset('assets/images/default-profile-picture.png', fit: BoxFit.cover),
                                      )
                                    : Image.asset(
                                        person['image'],
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
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.green),
                                      const SizedBox(width: 6),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Age: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.black54,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '${person['age']}',
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
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/patient_profile_family',
                                              arguments: {'uid': person['uid']},
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
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
                                          child: const Text('View'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _confirmRemovePatient(person['name'], person['uid']),
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
