import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();
  final List<Map<String, dynamic>> _linkedPatients = [];
  final List<Map<String, dynamic>> _todayTasks = [];
  final List<String> _alerts = [];
  String caregiverName = '';
  String? _selectedPatientId;

  Future<void> linkPatientToCaregiver(String email) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .where('role', isEqualTo: 'older_adult')
              .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No older adult found with this email')),
        );
        return;
      }

      final patientId = querySnapshot.docs.first.id;
      final currentUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('caregiver_patients').add({
        'caregiver_id': currentUser!.uid,
        'patient_id': patientId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient linked successfully')),
      );

      fetchLinkedPatients();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> fetchLinkedPatients() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final caregiverId = currentUser!.uid;

    final caregiverSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .get();

    if (caregiverSnapshot.exists) {
      setState(() {
        caregiverName = caregiverSnapshot.data()!['name'] ?? '';
      });
    }

    final links =
        await FirebaseFirestore.instance
            .collection('caregiver_patients')
            .where('caregiver_id', isEqualTo: caregiverId)
            .get();

    final Set<String> seenPatientIds = {};
    final List<Map<String, dynamic>> patients = [];

    for (var doc in links.docs) {
      final patientId = doc['patient_id'];
      if (seenPatientIds.contains(patientId)) continue; // Prevent duplicates
      seenPatientIds.add(patientId);

      final patientRef =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .get();
      if (patientRef.exists) {
        final data = patientRef.data()!..['id'] = patientRef.id;
        patients.add({
          'id': patientRef.id,
          'name': data['name'],
          'email': data['email'],
          'image':
              (data['profileImage'] != null &&
                      data['profileImage'].toString().startsWith('http'))
                  ? data['profileImage']
                  : 'assets/images/default-profile-picture.png',
          'dob': data['dob'] ?? '',
          'phone': data['phone'] ?? '', // <-- Add this line
        });
        await fetchTasksForPatient(data);
      }
    }

    setState(() {
      _linkedPatients.clear();
      _linkedPatients.addAll(patients);
    });
  }

  Future<void> fetchTasksForPatient(Map<String, dynamic> patient) async {
    final today = DateTime.now();
    final dateStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Buscar tasks do dia normalmente (não precisa de índice composto)
    final taskSnapshot =
        await FirebaseFirestore.instance
            .collection('tasks')
            .where('patient_id', isEqualTo: patient['id'])
            .where('date', isEqualTo: dateStr)
            .get();

    for (var doc in taskSnapshot.docs) {
      final data = doc.data();
      data['patient_name'] = patient['name'];
      // Ensure all relevant fields for UI
      data['type'] = 'task';
      data['status'] = data['status'] ?? 'pending';
      data['time'] = data['time'] ?? '';
      _todayTasks.add(data);

      if (data['status'] == 'missed') {
        _alerts.add(
          "${patient['name']} missed ${data['name']} at ${data['time']}",
        );
      }
    }

    // Buscar todos os logs e filtrar por data no app (evita erro de índice)
    final todayStart = DateTime(today.year, today.month, today.day);

    // Checkin logs
    final checkinSnapshot =
        await FirebaseFirestore.instance
            .collection('checkin_logs')
            .where('patient_id', isEqualTo: patient['id'])
            .get();

    for (var doc in checkinSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) {
        final time = timestamp.toDate();
        if (time.year == today.year &&
            time.month == today.month &&
            time.day == today.day) {
          final status = data['status'] ?? 'confirmed';
          _todayTasks.add({
            'name': '${data['timeOfDay']} Check-In',
            'patient_name': patient['name'],
            'time': '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
            'status': status,
          });
          if (status == 'missed') {
            _alerts.add(
              "${patient['name']} missed ${data['timeOfDay']} Check-In at ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
            );
          }
        }
      }
    }

    // Hydration logs
    final hydrationSnapshot =
        await FirebaseFirestore.instance
            .collection('hydration_logs')
            .where('patient_id', isEqualTo: patient['id'])
            .get();

    for (var doc in hydrationSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) {
        final time = timestamp.toDate();
        if (time.year == today.year &&
            time.month == today.month &&
            time.day == today.day) {
          final status = data['status'] ?? 'hydration';
          _todayTasks.add({
            'name': '${data['period']} Hydration',
            'patient_name': patient['name'],
            'time': '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
            'status': status,
          });
          if (status == 'missed') {
            _alerts.add(
              "${patient['name']} missed ${data['period']} Hydration at ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
            );
          }
        }
      }
    }

    // Nutrition logs
    final nutritionSnapshot =
        await FirebaseFirestore.instance
            .collection('nutrition_logs')
            .where('patient_id', isEqualTo: patient['id'])
            .get();

    for (var doc in nutritionSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) {
        final time = timestamp.toDate();
        if (time.year == today.year &&
            time.month == today.month &&
            time.day == today.day) {
          final status = data['status'] ?? 'nutrition';
          _todayTasks.add({
            'name': '${data['period'] ?? data['timeOfDay']} Nutrition',
            'patient_name': patient['name'],
            'time': '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
            'status': status,
          });
          if (status == 'missed') {
            _alerts.add(
              "${patient['name']} missed ${data['period'] ?? data['timeOfDay']} Nutrition at ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
            );
          }
        }
      }
    }

    // Ordenar _todayTasks e _alerts do mais recente para o mais antigo
    _todayTasks.sort((a, b) {
      final aTime = a['time'] ?? '';
      final bTime = b['time'] ?? '';
      // Formato HH:mm
      try {
        final aParts = aTime.split(':');
        final bParts = bTime.split(':');
        final aDt = DateTime(
          0,
          1,
          1,
          int.parse(aParts[0]),
          int.parse(aParts[1]),
        );
        final bDt = DateTime(
          0,
          1,
          1,
          int.parse(bParts[0]),
          int.parse(bParts[1]),
        );
        return bDt.compareTo(aDt);
      } catch (_) {
        return 0;
      }
    });
    _alerts.sort((a, b) {
      // Extrai hora do texto (últimos caracteres após 'at ')
      final aTime = a.split('at ').last;
      final bTime = b.split('at ').last;
      try {
        final aParts = aTime.split(':');
        final bParts = bTime.split(':');
        final aDt = DateTime(
          0,
          1,
          1,
          int.parse(aParts[0]),
          int.parse(aParts[1]),
        );
        final bDt = DateTime(
          0,
          1,
          1,
          int.parse(bParts[0]),
          int.parse(bParts[1]),
        );
        return bDt.compareTo(aDt);
      } catch (_) {
        return 0;
      }
    });
    setState(() {});
  }

  Future<void> addTaskForPatient() async {
    if (_selectedPatientId == null || _taskNameController.text.isEmpty) return;

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    await FirebaseFirestore.instance.collection('tasks').add({
      'patient_id': _selectedPatientId,
      'name': _taskNameController.text,
      'description': _taskDescriptionController.text,
      'date': dateStr,
      'time': timeStr,
      'status': 'pending',
    });

    _taskNameController.clear();
    _taskDescriptionController.clear();
    _selectedPatientId = null;
    fetchLinkedPatients();
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

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> checkAndMarkMissedTasks() async {
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    for (final patient in _linkedPatients) {
      // Tasks
      final taskSnapshot =
          await FirebaseFirestore.instance
              .collection('tasks')
              .where('patient_id', isEqualTo: patient['id'])
              .where('date', isEqualTo: dateStr)
              .get();
      for (var doc in taskSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final timeStr = data['time'] ?? '';
        if (status != 'confirmed' &&
            status != 'done' &&
            status != 'completed' &&
            status != 'missed' &&
            timeStr.isNotEmpty) {
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            final taskTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.tryParse(parts[0]) ?? 0,
              int.tryParse(parts[1]) ?? 0,
            );
            if (now.isAfter(taskTime)) {
              await doc.reference.update({'status': 'missed'});
            }
          }
        }
      }
      // Check-in logs
      final checkinSnapshot =
          await FirebaseFirestore.instance
              .collection('checkin_logs')
              .where('patient_id', isEqualTo: patient['id'])
              .get();
      for (var doc in checkinSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final timestamp = data['timestamp'];
        if (status != 'confirmed' &&
            status != 'done' &&
            status != 'completed' &&
            status != 'missed' &&
            timestamp is Timestamp) {
          final time = timestamp.toDate();
          if (time.year == now.year &&
              time.month == now.month &&
              time.day == now.day &&
              now.isAfter(time)) {
            await doc.reference.update({'status': 'missed'});
          }
        }
      }
      // Hydration logs
      final hydrationSnapshot =
          await FirebaseFirestore.instance
              .collection('hydration_logs')
              .where('patient_id', isEqualTo: patient['id'])
              .get();
      for (var doc in hydrationSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final timestamp = data['timestamp'];
        if (status != 'confirmed' &&
            status != 'done' &&
            status != 'completed' &&
            status != 'missed' &&
            timestamp is Timestamp) {
          final time = timestamp.toDate();
          if (time.year == now.year &&
              time.month == now.month &&
              time.day == now.day &&
              now.isAfter(time)) {
            await doc.reference.update({'status': 'missed'});
          }
        }
      }
      // Nutrition logs
      final nutritionSnapshot =
          await FirebaseFirestore.instance
              .collection('nutrition_logs')
              .where('patient_id', isEqualTo: patient['id'])
              .get();
      for (var doc in nutritionSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final timestamp = data['timestamp'];
        if (status != 'confirmed' &&
            status != 'done' &&
            status != 'completed' &&
            status != 'missed' &&
            timestamp is Timestamp) {
          final time = timestamp.toDate();
          if (time.year == now.year &&
              time.month == now.month &&
              time.day == now.day &&
              now.isAfter(time)) {
            await doc.reference.update({'status': 'missed'});
          }
        }
      }
    }
  }

  Future<void> checkAndMarkAllExpectedMissed() async {
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    // Períodos esperados
    final hydrationPeriods = ['Morning', 'Afternoon', 'Evening'];
    final nutritionPeriods = ['Breakfast', 'Lunch', 'Dinner'];
    final checkinPeriods = ['Morning', 'Afternoon', 'Evening'];
    // Horários limites (exemplo, ajuste conforme sua lógica)
    final hydrationTimes = {'Morning': 10, 'Afternoon': 16, 'Evening': 22};
    final nutritionTimes = {'Breakfast': 10, 'Lunch': 15, 'Dinner': 21};
    final checkinTimes = {'Morning': 10, 'Afternoon': 16, 'Evening': 22};
    for (final patient in _linkedPatients) {
      final patientId = patient['id'];
      // HYDRATION
      for (final period in hydrationPeriods) {
        final hydrationSnapshot =
            await FirebaseFirestore.instance
                .collection('hydration_logs')
                .where('patient_id', isEqualTo: patientId)
                .where('period', isEqualTo: period)
                .get();
        final exists = hydrationSnapshot.docs.any((doc) {
          final ts = doc['timestamp'];
          if (ts is Timestamp) {
            final t = ts.toDate();
            return t.year == now.year &&
                t.month == now.month &&
                t.day == now.day;
          }
          return false;
        });
        final hourLimit = hydrationTimes[period] ?? 23;
        if (!exists && now.hour >= hourLimit) {
          await FirebaseFirestore.instance.collection('hydration_logs').add({
            'patient_id': patientId,
            'period': period,
            'amount_ml': 0,
            'timestamp': Timestamp.fromDate(
              DateTime(now.year, now.month, now.day, hourLimit),
            ),
            'status': 'missed',
          });
        }
      }
      // NUTRITION
      for (final period in nutritionPeriods) {
        final nutritionSnapshot =
            await FirebaseFirestore.instance
                .collection('nutrition_logs')
                .where('patient_id', isEqualTo: patientId)
                .where('period', isEqualTo: period)
                .get();
        final exists = nutritionSnapshot.docs.any((doc) {
          final ts = doc['timestamp'];
          if (ts is Timestamp) {
            final t = ts.toDate();
            return t.year == now.year &&
                t.month == now.month &&
                t.day == now.day;
          }
          return false;
        });
        final hourLimit = nutritionTimes[period] ?? 23;
        if (!exists && now.hour >= hourLimit) {
          await FirebaseFirestore.instance.collection('nutrition_logs').add({
            'patient_id': patientId,
            'period': period,
            'timestamp': Timestamp.fromDate(
              DateTime(now.year, now.month, now.day, hourLimit),
            ),
            'status': 'missed',
          });
        }
      }
      // CHECK-IN
      for (final period in checkinPeriods) {
        final checkinSnapshot =
            await FirebaseFirestore.instance
                .collection('checkin_logs')
                .where('patient_id', isEqualTo: patientId)
                .where('timeOfDay', isEqualTo: period)
                .get();
        final exists = checkinSnapshot.docs.any((doc) {
          final ts = doc['timestamp'];
          if (ts is Timestamp) {
            final t = ts.toDate();
            return t.year == now.year &&
                t.month == now.month &&
                t.day == now.day;
          }
          return false;
        });
        final hourLimit = checkinTimes[period] ?? 23;
        if (!exists && now.hour >= hourLimit) {
          await FirebaseFirestore.instance.collection('checkin_logs').add({
            'patient_id': patientId,
            'timeOfDay': period,
            'timestamp': Timestamp.fromDate(
              DateTime(now.year, now.month, now.day, hourLimit),
            ),
            'status': 'missed',
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLinkedPatients().then((_) async {
      await checkAndMarkAllExpectedMissed();
      await checkAndMarkMissedTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

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
                  onPressed:
                      () =>
                          Navigator.pushNamed(context, '/caregiver_dashboard'),
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
                  onPressed: () => Navigator.pushNamed(context, '/patients'),
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
          NotificationDropdown(),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/home_screen'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${getGreeting()}, $caregiverName!',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          todayFormatted,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // NOVO LAYOUT: 2 linhas, 2 colunas, tasks ainda maior
                Expanded(
                  child: Column(
                    children: [
                      // Primeira linha: Patients | Recent Alerts
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            // Patients
                            Expanded(
                              flex: 1,
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(
                                  right: 10,
                                  bottom: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Patients',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 150,
                                        child: _linkedPatients.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No patients linked.',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              )
                                            : ListView.separated(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    _linkedPatients.length,
                                                separatorBuilder:
                                                    (_, __) => const SizedBox(
                                                      width: 18,
                                                    ),
                                                itemBuilder: (context, idx) {
                                                  final p = _linkedPatients[idx];
                                                  return Container(
                                                    width: 150,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        14,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color:
                                                              Colors.black12,
                                                          blurRadius: 3,
                                                          offset: Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey.shade200,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.start,
                                                      children: [
                                                        // Image takes 40% of the card height
                                                        SizedBox(
                                                          height: 60, // 40% of 150
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                const BorderRadius.vertical(
                                                              top: Radius.circular(
                                                                14,
                                                              ),
                                                            ),
                                                            child: p['image']
                                                                    .toString()
                                                                    .startsWith('http')
                                                                ? Image.network(
                                                                    p['image'],
                                                                    height: 60,
                                                                    width:
                                                                        double.infinity,
                                                                    fit: BoxFit.cover,
                                                                    errorBuilder:
                                                                        (context,
                                                                                error,
                                                                                stackTrace) =>
                                                                            const Icon(Icons
                                                                                .error),
                                                                  )
                                                                : Image.asset(
                                                                    p['image'],
                                                                    height: 60,
                                                                    width:
                                                                        double.infinity,
                                                                    fit: BoxFit.cover,
                                                                  ),
                                                          ),
                                                        ),
                                                        // Info takes 60% of the card height
                                                        Expanded(
                                                          child: Padding(
                                                            padding: const EdgeInsets
                                                                .symmetric(
                                                              vertical: 8,
                                                              horizontal: 8,
                                                            ),
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  p['name'],
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight.w700,
                                                                    fontSize: 15,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 2),
                                                                Text(
                                                                  p['email'] ?? '',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .grey[600],
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(Icons.phone,
                                                                        size: 15,
                                                                        color: Colors
                                                                            .green[400]),
                                                                    const SizedBox(
                                                                        width: 4),
                                                                    Text(
                                                                      p['phone'] ??
                                                                          'No phone',
                                                                      style:
                                                                          const TextStyle(
                                                                        color:
                                                                            Colors.grey,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
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
                            // Recent Alerts
                            Expanded(
                              flex: 1,
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(
                                  left: 10,
                                  bottom: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Recent Alerts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child:
                                            _alerts.isEmpty
                                                ? const Center(
                                                  child: Text(
                                                    'No recent alerts.',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                )
                                                : ListView(
                                                  children:
                                                      _alerts
                                                          .map(
                                                            (alert) => Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        4.0,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .warning,
                                                                    size: 18,
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      alert,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
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
                      // Segunda linha: Today's Tasks (full width, no Summary)
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            // Today's Tasks (now full width)
                            Expanded(
                              flex: 1,
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(
                                  top: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Today's Tasks",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: _todayTasks.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No tasks for today.',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              )
                                            : LayoutBuilder(
                                                builder: (
                                                  context,
                                                  constraints,
                                                ) {
                                                  return SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.vertical,
                                                    child: SizedBox(
                                                      width:
                                                          constraints.maxWidth,
                                                      child: DataTable(
                                                        columnSpacing:
                                                            constraints
                                                                .maxWidth *
                                                            0.06,
                                                        horizontalMargin: 0,
                                                        headingRowHeight: 44,
                                                        dataRowMinHeight: 44,
                                                        dataRowMaxHeight: 50,
                                                        columns: const [
                                                          DataColumn(
                                                            label: Text(
                                                              'Task',
                                                              style:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                            ),
                                                            numeric: false,
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Type',
                                                              style:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                            ),
                                                            numeric: false,
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Patient',
                                                              style:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                            ),
                                                            numeric: false,
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Time',
                                                              style:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                            ),
                                                            numeric: false,
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Status',
                                                              style:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                            ),
                                                            numeric: false,
                                                          ),
                                                        ],
                                                        rows: _todayTasks.map((
                                                          t,
                                                        ) {
                                                          IconData icon;
                                                          Color color;
                                                          Color rowColor;
                                                          String statusText;
                                                          String typeText;
                                                          switch (t['status']) {
                                                            case 'missed':
                                                              icon =
                                                                  Icons
                                                                      .warning_amber_rounded;
                                                              color = Colors.red;
                                                              statusText = 'Missed';
                                                              rowColor = Colors
                                                                  .red
                                                                  .withOpacity(
                                                                    0.07,
                                                                  );
                                                              break;
                                                            case 'hydration':
                                                              icon =
                                                                  Icons.local_drink;
                                                              color = Colors.blue;
                                                              statusText = 'Done';
                                                              rowColor = Colors
                                                                  .blue
                                                                  .withOpacity(
                                                                    0.07,
                                                                  );
                                                              break;
                                                            case 'nutrition':
                                                              icon =
                                                                  Icons.restaurant;
                                                              color = Colors.green;
                                                              statusText = 'Done';
                                                              rowColor = Colors
                                                                  .green
                                                                  .withOpacity(
                                                                    0.07,
                                                                  );
                                                              break;
                                                            case 'confirmed':
                                                            case 'done':
                                                            case 'completed':
                                                              icon =
                                                                  Icons.check_circle_outline;
                                                              color = Colors.green;
                                                              statusText = 'Done';
                                                              rowColor = Colors
                                                                  .green
                                                                  .withOpacity(
                                                                    0.07,
                                                                  );
                                                              break;
                                                            default:
                                                              icon = Icons.task_alt;
                                                              color = Colors.orange;
                                                              statusText = 'Pending';
                                                              rowColor = Colors
                                                                  .orange
                                                                  .withOpacity(
                                                                    0.07,
                                                                  );
                                                          }
                                                          if (t['status'] ==
                                                                  'hydration' ||
                                                              t['name']
                                                                  .toString()
                                                                  .toLowerCase()
                                                                  .contains(
                                                                    'hydration',
                                                                  )) {
                                                            typeText = 'Hydration';
                                                          } else if (t['status'] ==
                                                                  'nutrition' ||
                                                              t['name']
                                                                  .toString()
                                                                  .toLowerCase()
                                                                  .contains(
                                                                    'nutrition',
                                                                  )) {
                                                            typeText = 'Nutrition';
                                                          } else if (t['name']
                                                              .toString()
                                                              .toLowerCase()
                                                              .contains(
                                                                'check-in',
                                                              )) {
                                                            typeText = 'Check-in';
                                                          } else {
                                                            typeText = 'Other';
                                                          }
                                                          return DataRow(
                                                            color: MaterialStateProperty.resolveWith<Color?>(
                                                                (Set<MaterialState> states) {
                                                              return rowColor;
                                                            }),
                                                            cells: [
                                                              DataCell(
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      icon,
                                                                      color: color,
                                                                      size: 22,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        t['name'] ??
                                                                            '',
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              17,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Text(
                                                                  typeText,
                                                                  style: TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight:
                                                                        FontWeight.w600,
                                                                    color: color,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Text(
                                                                  t['patient_name'] ??
                                                                      '',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        17,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Text(
                                                                  t['time'] ??
                                                                      '',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        17,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 12,
                                                                    vertical: 6,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: color.withOpacity(
                                                                      0.18,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    statusText,
                                                                    style: TextStyle(
                                                                      color: color,
                                                                      fontWeight:
                                                                          FontWeight.w700,
                                                                      fontSize: 16,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        }).toList(),
                                                      ),
                                                  ));
                                                  },
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Removed the Summary Expanded here
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NotificationDropdown extends StatefulWidget {
  @override
  _NotificationDropdownState createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  bool _dropdownOpen = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('notifications')
              .where(
                'caregiver_id',
                isEqualTo: FirebaseAuth.instance.currentUser!.uid,
              )
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () async {
                setState(() {
                  _dropdownOpen = !_dropdownOpen;
                });
                if (_dropdownOpen) {
                  // Mark all as read
                  for (var doc in docs) {
                    await doc.reference.update({'read': true});
                  }
                  showDialog(
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setStateDialog) {
                          return AlertDialog(
                            title: const Text('Notifications'),
                            content: SizedBox(
                              width: 350,
                              child:
                                  docs.isEmpty
                                      ? const Text('No notifications')
                                      : ListView(
                                        shrinkWrap: true,
                                        children:
                                            docs.map((doc) {
                                              final data =
                                                  doc.data()
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >? ?? {};
                                              final message =
                                                  data['message'] ??
                                                  'No message';
                                              final type =
                                                  data['type'] ?? 'default';
                                              final timestamp =
                                                  data['timestamp'];
                                              final docRef = doc.reference;
                                              String timeString = '';
                                              if (timestamp is Timestamp) {
                                                final time = timestamp.toDate();
                                                timeString =
                                                    '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                                              }
                                              IconData icon;
                                              Color iconColor;
                                              switch (type) {
                                                case 'alert':
                                                  icon =
                                                      Icons
                                                          .warning_amber_rounded;
                                                  iconColor = Colors.red;
                                                  break;
                                                case 'task':
                                                  icon =
                                                      Icons
                                                          .check_circle_outline;
                                                  iconColor = Colors.green;
                                                  break;
                                                case 'hydration':
                                                  icon = Icons.local_drink;
                                                  iconColor = Colors.blue;
                                                  break;
                                                case 'nutrition':
                                                  icon = Icons.restaurant;
                                                  iconColor = Colors.orange;
                                                  break;
                                                case 'checkin':
                                                  icon = Icons.access_time;
                                                  iconColor = Colors.purple;
                                                  break;
                                                default:
                                                  icon = Icons.notifications;
                                                  iconColor = Colors.grey;
                                              }
                                              return ListTile(
                                                leading: Icon(
                                                  icon,
                                                  color: iconColor,
                                                ),
                                                title: Text(
                                                  message,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  timeString,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  ),
                                                  onPressed: () async {
                                                    await docRef.delete();
                                                    setStateDialog(
                                                      () {},
                                                    ); // Refresh dialog
                                                  },
                                                ),
                                              );
                                            }).toList(),
                                      ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    _dropdownOpen = false;
                                  });
                                },
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
            // Fix: Use safe fallback for 'read' field
            if (docs.where((d) => (d.data() as Map<String, dynamic>?)?['read'] ?? false == false).isNotEmpty)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${docs.where((d) => (d.data() as Map<String, dynamic>?)?['read'] ?? false == false).length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
