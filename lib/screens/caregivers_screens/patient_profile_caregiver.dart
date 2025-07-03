import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PatientProfileCaregiver extends StatefulWidget {
  const PatientProfileCaregiver({super.key});

  @override
  State<PatientProfileCaregiver> createState() => _PatientProfileCaregiverState();
}

class _PatientProfileCaregiverState extends State<PatientProfileCaregiver> {
  Map<String, dynamic>? patient;
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> alerts = [];
  List<Map<String, dynamic>> caregivers = [];
  List<Map<String, dynamic>> medications = [];
  bool loading = true;

  String? patientUid;
  bool _didFetch = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetch) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // Accepts both 'uid' and 'id' as parameter for compatibility
      if (args is Map && (args['uid'] != null || args['id'] != null)) {
        patientUid = (args['uid'] ?? args['id'])?.toString();
        setState(() {
          loading = true;
        });
        fetchAll().then((_) {
          if (mounted) setState(() => loading = false);
        });
      } else {
        setState(() {
          loading = false;
        });
      }
      _didFetch = true;
    }
  }

  Future<void> fetchAll() async {
    try {
      await fetchPatient();
      await fetchTasks();
      await fetchGeneratedAlerts();
      await fetchCaregivers();
      await fetchMedications();
    } catch (e, st) {
      debugPrint('Error in fetchAll: $e\n$st');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> fetchPatient() async {
    if (patientUid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(patientUid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        patient = {
          ...data,
          'id': doc.id,
          'age': _calculateAge(data['dob']),
        };
      });
    }
  }

  Future<void> fetchTasks() async {
    if (patientUid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('patient_id', isEqualTo: patientUid)
        .get();
    setState(() {
      tasks = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  Future<void> fetchGeneratedAlerts() async {
    if (patientUid == null) return;
    List<Map<String, dynamic>> generatedAlerts = [];
    final patientName = patient?['name'] ?? '';

    // Tasks
    final taskSnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('patient_id', isEqualTo: patientUid)
        .get();
    for (var doc in taskSnapshot.docs) {
      final data = doc.data();
      if ((data['status'] ?? '') == 'missed') {
        generatedAlerts.add({
          'message': "$patientName missed ${data['name']} at ${data['time'] ?? ''}",
          'date': data['date'],
        });
      }
    }

    // Check-in logs
    final checkinSnapshot = await FirebaseFirestore.instance
        .collection('checkin_logs')
        .where('patient_id', isEqualTo: patientUid)
        .get();
    for (var doc in checkinSnapshot.docs) {
      final data = doc.data();
      if ((data['status'] ?? '') == 'missed') {
        final timestamp = data['timestamp'];
        String timeStr = '';
        if (timestamp is Timestamp) {
          final t = timestamp.toDate();
          timeStr = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
        }
        generatedAlerts.add({
          'message': "$patientName missed ${data['timeOfDay']} Check-In at $timeStr",
          'date': timestamp,
        });
      }
    }

    // Hydration logs
    final hydrationSnapshot = await FirebaseFirestore.instance
        .collection('hydration_logs')
        .where('patient_id', isEqualTo: patientUid)
        .get();
    for (var doc in hydrationSnapshot.docs) {
      final data = doc.data();
      if ((data['status'] ?? '') == 'missed') {
        final timestamp = data['timestamp'];
        String timeStr = '';
        if (timestamp is Timestamp) {
          final t = timestamp.toDate();
          timeStr = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
        }
        generatedAlerts.add({
          'message': "$patientName missed ${data['period']} Hydration at $timeStr",
          'date': timestamp,
        });
      }
    }

    // Nutrition logs
    final nutritionSnapshot = await FirebaseFirestore.instance
        .collection('nutrition_logs')
        .where('patient_id', isEqualTo: patientUid)
        .get();
    for (var doc in nutritionSnapshot.docs) {
      final data = doc.data();
      if ((data['status'] ?? '') == 'missed') {
        final timestamp = data['timestamp'];
        String timeStr = '';
        if (timestamp is Timestamp) {
          final t = timestamp.toDate();
          timeStr = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
        }
        generatedAlerts.add({
          'message': "$patientName missed ${(data['period'] ?? data['timeOfDay'])} Nutrition at $timeStr",
          'date': timestamp,
        });
      }
    }

    // Sort by date descending
    generatedAlerts.sort((a, b) {
      final aDate = a['date'];
      final bDate = b['date'];
      if (aDate is Timestamp && bDate is Timestamp) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });

    setState(() {
      alerts = generatedAlerts;
    });
  }

  Future<void> fetchAlerts() async {
    if (patientUid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('alerts')
        .where('patient_id', isEqualTo: patientUid)
        .limit(10)
        .get();
    setState(() {
      alerts = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> fetchCaregivers() async {
    if (patientUid == null) return;
    List<Map<String, dynamic>> all = [];

    // Fetch caregivers from both possible relation collections
    final caregiversPatientsSnapshot = await FirebaseFirestore.instance
        .collection('caregivers_patients')
        .where('patient_id', isEqualTo: patientUid)
        .get();

    final caregiverPatientsSnapshot = await FirebaseFirestore.instance
        .collection('caregiver_patients')
        .where('patient_id', isEqualTo: patientUid)
        .get();

    // Merge all caregiver ids from both collections
    final caregiverIds = [
      ...caregiversPatientsSnapshot.docs.map((doc) => doc['caregiver_id']),
      ...caregiverPatientsSnapshot.docs.map((doc) => doc['caregiver_id']),
    ].where((id) => id != null).toSet();

    // Fetch family members
    final familyRelationSnapshot = await FirebaseFirestore.instance
        .collection('family_patients')
        .where('patient_id', isEqualTo: patientUid)
        .get();

    final familyIds = familyRelationSnapshot.docs
        .map((doc) => doc['family_id'])
        .where((id) => id != null)
        .toSet();

    // Combine all unique user ids
    final allIds = {...caregiverIds, ...familyIds}.toList();

    if (allIds.isNotEmpty) {
      for (var i = 0; i < allIds.length; i += 10) {
        final batchIds = allIds.skip(i).take(10).toList();
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        all.addAll(usersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['name'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'image': (data['profileImage'] ?? data['image'] ?? '').toString(),
            'uid': doc.id,
            'role': data['role'] ?? '',
          };
        }));
      }
    }

    setState(() {
      caregivers = all;
    });
  }

  Future<void> fetchMedications() async {
    if (patientUid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('medications')
        .where('patient_id', isEqualTo: patientUid)
        .get();
    setState(() {
      medications = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  int _calculateAge(String? dob) {
    if (dob == null) return 0;
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

  String _formatDate(dynamic date, {bool timeOnly = false}) {
    if (date == null) return '-';
    DateTime dt;
    if (date is Timestamp) {
      dt = date.toDate();
    } else if (date is DateTime) {
      dt = date;
    } else {
      return date.toString();
    }
    if (timeOnly) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Color _getMedicationStatusColor(dynamic taken) {
    if (taken == true) return Colors.green;
    return Colors.orange;
  }

  String _getMedicationStatusText(dynamic taken) {
    if (taken == true) return 'Taken';
    return 'Pending';
  }

  Future<void> unlinkPatient() async {
    final caregiverId = FirebaseAuth.instance.currentUser?.uid;
    final patientId = patient!['id'];

    final query =
        await FirebaseFirestore.instance
            .collection('caregiver_patients')
            .where('caregiver_id', isEqualTo: caregiverId)
            .where('patient_id', isEqualTo: patientId)
            .get();

    for (var doc in query.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showAddTaskDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final TextEditingController dateController = TextEditingController();
    final TextEditingController timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFF7FAFC),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF2F8369),
                    child: Icon(Icons.add_task, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Add New Task',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F8369),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in the details below to add a new task.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Task Name *',
                      labelStyle: const TextStyle(fontSize: 18, color: Colors.black87),
                      prefixIcon: const Icon(Icons.edit, color: Color(0xFF2F8369)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                      prefixIcon: const Icon(Icons.notes, color: Color(0xFF2F8369)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                selectedDate = pickedDate;
                                dateController.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: dateController,
                              readOnly: true,
                              style: const TextStyle(fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'Date *',
                                labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF2F8369)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                selectedTime = pickedTime;
                                timeController.text = pickedTime.format(context);
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: timeController,
                              readOnly: true,
                              style: const TextStyle(fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'Hour',
                                labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                                prefixIcon: const Icon(Icons.access_time, color: Color(0xFF2F8369)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
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
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Add Task', style: TextStyle(fontSize: 20, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F8369),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty || selectedDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name and Date are required.'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (selectedTime != null) {
                            final dateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );
                            await FirebaseFirestore.instance.collection('tasks').add({
                              'name': nameController.text.trim(),
                              'description': descController.text.trim(),
                              'date': Timestamp.fromDate(dateTime),
                              'patient_id': patientUid,
                              'status': 'pending',
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Task added for ${patient?['name'] ?? 'the patient'}!'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            fetchAll();
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
      ));
  }

  void _showAddMedicationDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController dosageController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    TimeOfDay? firstHour;
    final TextEditingController startDateController = TextEditingController();
    final TextEditingController endDateController = TextEditingController();
    final TextEditingController firstHourController = TextEditingController();
    final TextEditingController intervalController = TextEditingController();
    final TextEditingController timesPerDayController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFF7FAFC),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.medication, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Add Medication',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in the details below to add a new medication.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Medication Name *',
                      labelStyle: const TextStyle(fontSize: 18, color: Colors.black87),
                      prefixIcon: const Icon(Icons.edit, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dosageController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Dosage *',
                      labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                      prefixIcon: const Icon(Icons.medical_services, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                      prefixIcon: const Icon(Icons.notes, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                startDate = pickedDate;
                                startDateController.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: startDateController,
                              readOnly: true,
                              style: const TextStyle(fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'Start Date *',
                                labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                                prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? (startDate ?? DateTime.now()),
                              firstDate: startDate ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                endDate = pickedDate;
                                endDateController.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: endDateController,
                              readOnly: true,
                              style: const TextStyle(fontSize: 18),
                              decoration: InputDecoration(
                                labelText: 'End Date *',
                                labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                                prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: firstHour ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          firstHour = pickedTime;
                          firstHourController.text = pickedTime.format(context);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: firstHourController,
                        readOnly: true,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'First Hour *',
                          labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                          prefixIcon: const Icon(Icons.access_time, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: intervalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Interval (hours) *',
                            labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                            prefixIcon: const Icon(Icons.repeat, color: Colors.blue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: timesPerDayController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Times per day *',
                            labelStyle: const TextStyle(fontSize: 17, color: Colors.black87),
                            prefixIcon: const Icon(Icons.format_list_numbered, color: Colors.blue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
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
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Add Medication', style: TextStyle(fontSize: 20, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty ||
                              dosageController.text.trim().isEmpty ||
                              startDate == null ||
                              endDate == null ||
                              firstHour == null ||
                              intervalController.text.trim().isEmpty ||
                              timesPerDayController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All fields are required.'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          await FirebaseFirestore.instance.collection('medications').add({
                            'name': nameController.text.trim(),
                            'dosage': dosageController.text.trim(),
                            'description': descController.text.trim(),
                            'start_date': Timestamp.fromDate(startDate!),
                            'end_date': Timestamp.fromDate(endDate!),
                            'first_hour': '${firstHour!.hour.toString().padLeft(2, '0')}:${firstHour!.minute.toString().padLeft(2, '0')}',
                            'interval_hours': int.tryParse(intervalController.text.trim()) ?? 0,
                            'times_per_day': int.tryParse(timesPerDayController.text.trim()) ?? 0,
                            'patient_id': patientUid,
                            'taken': false,
                          });
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Medication added for ${patient?['name'] ?? 'the patient'}!'),
                              backgroundColor: Colors.blue,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          fetchAll();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
  }

  Future<void> _showRemoveConfirmation() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  'Remove ${patient?['name'] ?? 'patient'}?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to remove this patient from your care list? You will no longer have access to their information.',
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.black54),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await unlinkPatient();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${patient?['name'] ?? 'Patient'} removed successfully.'), backgroundColor: Colors.green),
                        );
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
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (patientUid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patient Profile'),
        ),
        body: const Center(
          child: Text('No patient selected.'),
        ),
      );
    }
    if (patient == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patient Profile'),
        ),
        body: const Center(
          child: Text('Patient not found.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFCFCFCF),
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
              onPressed: () => Navigator.pushNamed(context, '/caregiver_dashboard'),
              child: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/manage_patients_caregiver'),
              child: const Text(
                'Patients',
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
            icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/home_screen'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar (vertical banner)
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 161, 161, 161),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: (() {
                          final img = (patient!['profileImage'] ?? patient!['image'] ?? '').toString();
                          if (img.isNotEmpty && img.startsWith('http')) {
                            return NetworkImage(img);
                          } else if (img.isNotEmpty) {
                            return AssetImage(img);
                          } else {
                            return const AssetImage('assets/images/default-profile-picture.png');
                          }
                        })() as ImageProvider,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      patient!['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.email, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            patient!['email'],
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (patient!['phone'] ?? '').toString().isNotEmpty ? patient!['phone'] : '-',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.cake, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Age: ${patient!['age']}',
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddMedicationDialog,
                        icon: const Icon(Icons.medication, color: Colors.white),
                        label: const Text('Add Medication', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddTaskDialog,
                        icon: const Icon(Icons.add_task, color: Colors.white),
                        label: const Text('Add Task', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showRemoveConfirmation();
                        },
                        icon: const Icon(Icons.delete_forever, color: Colors.white),
                        label: const Text('Remove Patient', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Main content on the right
              Expanded(
                child: Container(
                  color: const Color(0xFFF7F6FB),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FIRST ROW: Assigned Tasks and Medications side by side
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: SizedBox(
                              height: 400,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Assigned Tasks Card
                                  Expanded(
                                    flex: 3,
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(Icons.checklist, color: Colors.green, size: 26),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Assigned Tasks',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final nameCol = constraints.maxWidth * 0.32;
                                                final dateCol = constraints.maxWidth * 0.18;
                                                final hourCol = constraints.maxWidth * 0.18;
                                                final statusCol = constraints.maxWidth * 0.22;
                                                if (tasks.isEmpty) {
                                                  return Container(
                                                    height: 260,
                                                    alignment: Alignment.center,
                                                    child: const Text(
                                                      'No tasks assigned.',
                                                      style: TextStyle(color: Colors.grey),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  );
                                                }
                                                return Column(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        SizedBox(
                                                          width: nameCol,
                                                          child: const Text(
                                                            'Task',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.black54,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: dateCol,
                                                          child: const Text(
                                                            'Date',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.black54,
                                                              fontSize: 15,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: hourCol,
                                                          child: const Text(
                                                            'Hour',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.black54,
                                                              fontSize: 15,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: statusCol,
                                                          child: const Text(
                                                            'Status',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.black54,
                                                              fontSize: 15,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      height: 260,
                                                      child: tasks.isEmpty
                                                          ? const SizedBox.shrink()
                                                          : ListView.builder(
                                                              itemCount: tasks.length,
                                                              itemBuilder: (context, idx) {
                                                                final task = tasks[idx];
                                                                return Container(
                                                                  margin: const EdgeInsets.only(bottom: 8),
                                                                  child: Row(
                                                                    children: [
                                                                      SizedBox(
                                                                        width: nameCol,
                                                                        child: Text(
                                                                          task['name'] ?? '-',
                                                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: dateCol,
                                                                        child: Text(
                                                                          _formatDate(task['date'], timeOnly: false).split(' ').first,
                                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: hourCol,
                                                                        child: Text(
                                                                          _formatDate(task['date'], timeOnly: true),
                                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: statusCol,
                                                                        child: Container(
                                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                          decoration: BoxDecoration(
                                                                            color: _getMedicationStatusColor(task['status']).withOpacity(0.15),
                                                                            borderRadius: BorderRadius.circular(6),
                                                                          ),
                                                                          child: Text(
                                                                            _getMedicationStatusText(task['status']),
                                                                            style: TextStyle(
                                                                              color: _getMedicationStatusColor(task['status']),
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 13,
                                                                            ),
                                                                            textAlign: TextAlign.center,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ));
                                                              },
                                                            ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  // Medications Card
                                  Expanded(
                                    flex: 2,
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(Icons.medication, color: Colors.blue, size: 26),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Medications',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
                                            Container(
                                              height: 260,
                                              child: medications.isEmpty
                                                  ? Container(
                                                      height: 260,
                                                      alignment: Alignment.center,
                                                      child: const Text(
                                                        'No medications scheduled.',
                                                        style: TextStyle(color: Colors.grey),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      itemCount: medications.length,
                                                      itemBuilder: (context, idx) {
                                                        final med = medications[idx];
                                                        return Container(
                                                          margin: const EdgeInsets.only(bottom: 10),
                                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                          decoration: BoxDecoration(
                                                            color: med['taken'] == true ? Colors.green[50] : Colors.blue[50],
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Flexible(
                                                                    child: Text(
                                                                      '${med['name'] ?? '-'} (${med['dosage'] ?? ''})',
                                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                  // Exibe o horário da primeira toma e o intervalo
                                                                  Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                                    children: [
                                                                      if (med['first_hour'] != null)
                                                                        Text(
                                                                          'First: ${med['first_hour']}',
                                                                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                                                                        ),
                                                                      if (med['interval_hours'] != null && med['times_per_day'] != null)
                                                                        Text(
                                                                          '${med['times_per_day']}x • ${med['interval_hours']}h',
                                                                          style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                  med['taken'] == true
                                                                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                                                      : const Icon(Icons.radio_button_unchecked, color: Colors.blue, size: 20),
                                                                ],
                                                              ),
                                                              if ((med['description'] ?? '').toString().isNotEmpty)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 4.0),
                                                                  child: Text(
                                                                    med['description'],
                                                                    style: const TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic),
                                                                    overflow: TextOverflow.ellipsis,
                                                                    maxLines: 2,
                                                                  ),
                                                                ),
                                                              if (med['start_date'] != null && med['end_date'] != null)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 2.0),
                                                                  child: Text(
                                                                    'From ${_formatDate(med['start_date'], timeOnly: false).split(' ').first} to ${_formatDate(med['end_date'], timeOnly: false).split(' ').first}',
                                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                                  ),
                                                                ),
                                                            ],
                                                          ));
                                                      },
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // SECOND ROW: Caregivers on the left, Alert History on the right
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Caregivers Card (left)
                                Expanded(
                                  flex: 3,
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: SizedBox(
                                        height: 260,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(Icons.group, color: Colors.indigo, size: 26),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Caregivers',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
                                            Expanded(
                                              child: caregivers.isEmpty
                                                  ? const Text('No caregivers associated.', style: TextStyle(color: Colors.grey))
                                                  : GridView.builder(
                                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: 3,
                                                        mainAxisSpacing: 16,
                                                        crossAxisSpacing: 16,
                                                        childAspectRatio: 0.95,
                                                      ),
                                                      itemCount: caregivers.length,
                                                      itemBuilder: (context, idx) {
                                                        final cg = caregivers[idx];
                                                        return Container(
                                                          constraints: const BoxConstraints(
                                                            minHeight: 0,
                                                            maxHeight: 170,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                Colors.blue.shade50,
                                                                Colors.white,
                                                              ],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            borderRadius: BorderRadius.circular(18),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.grey.withOpacity(0.10),
                                                                blurRadius: 10,
                                                                offset: const Offset(0, 4),
                                                              ),
                                                            ],
                                                            border: Border.all(
                                                              color: Colors.blue.withOpacity(0.25),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                          child: SingleChildScrollView(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                CircleAvatar(
                                                                  radius: 36,
                                                                  backgroundColor: Colors.blue[50],
                                                                  backgroundImage: (cg['image'] as String).startsWith('http')
                                                                      ? NetworkImage(cg['image'])
                                                                      : AssetImage(
                                                                          cg['image'].isNotEmpty
                                                                              ? cg['image']
                                                                              : 'assets/images/default-profile-picture.png',
                                                                        ) as ImageProvider,
                                                                ),
                                                                const SizedBox(height: 10),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    Flexible(
                                                                      child: Text(
                                                                        cg['name'],
                                                                        style: TextStyle(
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 16,
                                                                          color: Colors.blue[900],
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                        textAlign: TextAlign.center,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Icon(
                                                                      cg['role'] == 'family'
                                                                          ? Icons.family_restroom
                                                                          : Icons.medical_services,
                                                                      size: 16,
                                                                      color: Colors.blue,
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 6),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    const Icon(Icons.email, size: 15, color: Colors.blueGrey),
                                                                    const SizedBox(width: 4),
                                                                    Flexible(
                                                                      child: Text(
                                                                        cg['email'],
                                                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                                        overflow: TextOverflow.ellipsis,
                                                                        textAlign: TextAlign.center,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    const Icon(Icons.phone, size: 15, color: Colors.teal),
                                                                    const SizedBox(width: 4),
                                                                    Flexible(
                                                                      child: Text(
                                                                        cg['phone'].toString().isNotEmpty ? cg['phone'] : '-',
                                                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                                        overflow: TextOverflow.ellipsis,
                                                                        textAlign: TextAlign.center,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Alert History Card (right)
                                Expanded(
                                  flex: 2,
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
                                              SizedBox(width: 8),
                                              Text(
                                                'Alert History',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 18),
                                          if (alerts.isEmpty)
                                            const Text('No alerts.', style: TextStyle(color: Colors.grey)),
                                          Container(
                                            height: 180,
                                            child: alerts.isEmpty
                                                ? const SizedBox.shrink()
                                                : ListView.builder(
                                                    itemCount: alerts.length,
                                                    itemBuilder: (context, idx) {
                                                      final alert = alerts[idx];
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.warning,
                                                              size: 18,
                                                              color: Colors.red,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                alert['message'] ?? '-',
                                                                style: const TextStyle(fontSize: 16),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
