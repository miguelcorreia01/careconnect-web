import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String? _userId;
  late Future<void> _loadUserFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserFuture = _loadUserId();
  }

  Future<void> _loadUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Busca o uid do Firestore (não do auth)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        setState(() {
          _userId = userDoc.docs.first['uid'];
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _medicationStream() {
    if (_userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('medications')
        .where('patient_id', isEqualTo: _userId)
        .snapshots();
  }

  Future<void> _confirmMedication(String docId) async {
    await FirebaseFirestore.instance
        .collection('medications')
        .doc(docId)
        .update({'taken': true});
  }

  // Simula envio de alerta (na prática, aqui só mostra um SnackBar)
  void _sendAlert(String medName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alerta: $medName não foi tomada!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _canConfirm(DateTime medTime, bool taken) {
    final now = DateTime.now();
    final start = medTime;
    final end = medTime.add(const Duration(hours: 2));
    return !taken && now.isAfter(start) && now.isBefore(end);
  }

  bool _missedMedication(DateTime medTime, bool taken) {
    final now = DateTime.now();
    final end = medTime.add(const Duration(hours: 2));
    return !taken && now.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
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
              child: const Text(
                'Dashboard',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/manage_caregivers');
              },
              child: const Text(
                'Caregivers',
                style: TextStyle(color: Colors.black),
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
      body: FutureBuilder(
        future: _loadUserFuture,
        builder: (context, snapshot) {
          if (_userId == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // Seletor de data
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        });
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 20),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.add(const Duration(days: 1));
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "Today's Medication",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Confirm your medication intake below.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _medicationStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No medications scheduled for this day.',
                            style: TextStyle(fontSize: 22, color: Colors.black54, fontWeight: FontWeight.w500),
                          ),
                        );
                      }
                      final meds = snapshot.data!.docs;

                      // Gera todas as tomas do dia selecionado para todos os medicamentos
                      final day = _selectedDate;
                      final todayMeds = <Map<String, dynamic>>[];

                      // --- CORREÇÃO: garantir que todas as tomas de todos os medicamentos aparecem ---
                      // Adiciona cada toma como um item separado, mantendo a ordem por horário
                      for (final doc in meds) {
                        final data = doc.data();
                        final startDate = (data['start_date'] as Timestamp).toDate();
                        final endDate = (data['end_date'] as Timestamp).toDate();
                        if (day.isBefore(startDate) || day.isAfter(endDate)) continue;

                        final interval = (data['interval_hours'] ?? 0);
                        final times = (data['times_per_day'] ?? 1);

                        // Calcular o horário da primeira toma do dia selecionado
                        DateTime firstTake;
                        final firstHourStr = data['first_hour'] ?? "08:00";
                        final firstHourParts = firstHourStr.split(':');
                        int hour = int.tryParse(firstHourParts[0]) ?? 8;
                        int minute = int.tryParse(firstHourParts[1]) ?? 0;
                        firstTake = DateTime(day.year, day.month, day.day, hour, minute);

                        // Corrigir o cast do taken_list para evitar o erro de tipo
                        final takenListRaw = data['taken_list'];
                        final takenList = takenListRaw is Map
                            ? Map<String, dynamic>.from(takenListRaw)
                            : <String, dynamic>{};
                        final takenDayRaw = takenList[DateFormat('yyyy-MM-dd').format(day)];
                        final takenDayMap = takenDayRaw is Map
                            ? Map<String, dynamic>.from(takenDayRaw)
                            : <String, dynamic>{};

                        for (int i = 0; i < times; i++) {
                          final medTime = firstTake.add(Duration(hours: i * (interval as num).toInt()));
                          if (medTime.day == day.day && medTime.month == day.month && medTime.year == day.year) {
                            final taken = takenDayMap['$i'] == true;
                            todayMeds.add({
                              ...data,
                              'docId': doc.id,
                              'medTime': medTime,
                              'taken': taken,
                              'doseIndex': i,
                            });
                          }
                        }
                      }

                      // --- NOVO: ordenar todas as tomas por horário para exibir corretamente no horizontal scroll ---
                      todayMeds.sort((a, b) => (a['medTime'] as DateTime).compareTo(b['medTime'] as DateTime));

                      return SizedBox(
                        height: 220, // aumenta a altura dos cards
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: todayMeds.length,
                          itemBuilder: (context, idx) {
                            final med = todayMeds[idx];
                            final name = med['name'] ?? '';
                            final dosage = med['dosage'] ?? '';
                            final description = med['description'] ?? '';
                            final taken = med['taken'] ?? false;
                            final medTime = med['medTime'] as DateTime;
                            final canConfirm = _canConfirm(medTime, taken);
                            final missed = _missedMedication(medTime, taken);

                            return Container(
                              width: MediaQuery.of(context).size.width / 3.1, // 3 cards por linha
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: missed
                                        ? Colors.red.shade200
                                        : taken
                                            ? Colors.green.shade200
                                            : Colors.blue.shade100,
                                    width: 1.5,
                                  ),
                                ),
                                color: missed
                                    ? Colors.red.shade50
                                    : taken
                                        ? Colors.green.shade50
                                        : Colors.blue.shade50,
                                child: Padding(
                                  padding: const EdgeInsets.all(16), // aumenta o padding
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medication,
                                        size: 40,
                                        color: missed
                                            ? Colors.red
                                            : taken
                                                ? Colors.green
                                                : Colors.blue,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: missed
                                              ? Colors.red[900]
                                              : taken
                                                  ? Colors.green[900]
                                                  : Colors.blue[900],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        dosage,
                                        style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      if (description.toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6.0),
                                          child: Text(
                                            description,
                                            style: const TextStyle(fontSize: 16, color: Colors.black54, fontStyle: FontStyle.italic),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      Text(
                                        DateFormat('HH:mm').format(medTime),
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      if (taken)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.check_circle, color: Colors.green, size: 22),
                                            SizedBox(width: 4),
                                            Text('Taken', style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      else if (missed)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.cancel, color: Colors.red, size: 22),
                                            SizedBox(width: 4),
                                            Text('Missed', style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: canConfirm
                                              ? () async {
                                                  // Atualiza apenas a toma específica no taken_list
                                                  final docId = med['docId'];
                                                  final doseIndex = med['doseIndex'];
                                                  final dateKey = DateFormat('yyyy-MM-dd').format(med['medTime']);
                                                  final docRef = FirebaseFirestore.instance.collection('medications').doc(docId);
                                                  await FirebaseFirestore.instance.runTransaction((transaction) async {
                                                    final snap = await transaction.get(docRef);
                                                    final data = snap.data() as Map<String, dynamic>;
                                                    final takenList = Map<String, dynamic>.from(data['taken_list'] ?? {});
                                                    final takenDayMap = Map<String, dynamic>.from(takenList[dateKey] ?? {});
                                                    takenDayMap['$doseIndex'] = true;
                                                    takenList[dateKey] = takenDayMap;
                                                    transaction.update(docRef, {'taken_list': takenList});
                                                  });
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Medication "$name" confirmed!'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                  setState(() {});
                                                }
                                              : null,
                                          child: canConfirm
                                              ? const Text('Confirm', style: TextStyle(fontSize: 18, color: Colors.white))
                                              : missed
                                                  ? Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: const [
                                                        Icon(Icons.cancel, color: Colors.red, size: 22),
                                                        SizedBox(width: 4),
                                                        Text('Missed', style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                                                      ],
                                                    )
                                                  : const Text('Confirm', style: TextStyle(fontSize: 18, color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: missed
                                                ? Colors.red
                                                : canConfirm
                                                    ? Colors.blue
                                                    : Colors.grey,
                                            minimumSize: const Size(100, 40),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
