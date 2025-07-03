import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  final Map<String, bool> _hydrationConfirmed = {
    'Morning': false,
    'Afternoon': false,
    'Evening': false,
  };

  bool _isWithinTimeRange(String period) {
    final now = DateTime.now();
    final hour = now.hour;

    if (period == 'Morning') {
      return hour >= 8 && hour < 12;
    } else if (period == 'Afternoon') {
      return hour >= 12 && hour < 18;
    } else if (period == 'Evening') {
      return hour >= 18 && hour < 22;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _fetchHydrationConfirmations();
  }

  Future<void> _fetchHydrationConfirmations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final query =
        await FirebaseFirestore.instance
            .collection('hydration_logs')
            .where('patient_id', isEqualTo: user.uid)
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();
    final Map<String, bool> confirmed = {
      'Morning': false,
      'Afternoon': false,
      'Evening': false,
    };
    for (var doc in query.docs) {
      final period = doc['period'];
      print('Firestore hydration log: period=$period, data=${doc.data()}');
      if (confirmed.containsKey(period) && doc['status'] == 'confirmed') {
        confirmed[period] = true;
      }
    }
    setState(() {
      _hydrationConfirmed.clear();
      _hydrationConfirmed.addAll(confirmed);
    });
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Center(
              child: Text(
                "Hydration",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Confirm your hydration throughout the day.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHydrationBox(
                    context,
                    period: 'Morning',
                    time: '08:00 - 12:00',
                    amount: '750 ml',
                  ),
                  _buildHydrationBox(
                    context,
                    period: 'Afternoon',
                    time: '12:00 - 18:00',
                    amount: '1000 ml',
                  ),
                  _buildHydrationBox(
                    context,
                    period: 'Evening',
                    time: '18:00 - 22:00',
                    amount: '250 ml',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHydrationBox(
    BuildContext context, {
    required String period,
    required String time,
    required String amount,
  }) {
    final isConfirmed = _hydrationConfirmed[period] ?? false;

    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.local_drink, size: 48, color: Colors.blue.shade700),
          const SizedBox(height: 16),
          Text(
            period,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(time, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 12),
          Text(amount, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child:
                isConfirmed
                    ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 40,
                    )
                    : ElevatedButton(
                      onPressed:
                          _isWithinTimeRange(period)
                              ? () async {
                                if (_hydrationConfirmed[period] == true) return;
                                setState(() {
                                  _hydrationConfirmed[period] = true;
                                });
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  final amountMl =
                                      {
                                        'Morning': 750,
                                        'Afternoon': 1000,
                                        'Evening': 250,
                                      }[period]!;
                                  await FirebaseFirestore.instance
                                      .collection('hydration_logs')
                                      .add({
                                        'patient_id': user.uid,
                                        'period': period,
                                        'amount_ml': amountMl,
                                        'timestamp': Timestamp.now(),
                                        'status': 'confirmed',
                                      });
                                  final userDoc =
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .get();
                                  final patientName =
                                      userDoc.data()?['name'] ?? 'Older adult';
                                  final relationSnapshot =
                                      await FirebaseFirestore.instance
                                          .collection('caregiver_patients')
                                          .where(
                                            'patient_id',
                                            isEqualTo: user.uid,
                                          )
                                          .get();
                                  for (var doc in relationSnapshot.docs) {
                                    final caregiverId = doc['caregiver_id'];
                                    await NotificationService().createNotification(
                                      caregiverId: caregiverId,
                                      patientId: user.uid,
                                      message:
                                          '$patientName confirmed $period hydration',
                                      type: 'hydration',
                                    );
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$period hydration confirmed and saved!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
