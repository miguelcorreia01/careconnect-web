import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final Map<String, bool> _mealConfirmed = {
    'Breakfast': false,
    'Lunch': false,
    'Dinner': false,
  };

  bool _isWithinMealTime(String period) {
    final hour = DateTime.now().hour;

    if (period == 'Breakfast') return hour >= 7 && hour < 10;
    if (period == 'Lunch') return hour >= 12 && hour < 15;
    if (period == 'Dinner') return hour >= 19 && hour < 21;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _fetchMealConfirmations();
  }

  Future<void> _fetchMealConfirmations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final query =
        await FirebaseFirestore.instance
            .collection('nutrition_logs')
            .where('patient_id', isEqualTo: user.uid)
            .get();
    final Map<String, bool> confirmed = {
      'Breakfast': false,
      'Lunch': false,
      'Dinner': false,
    };
    for (var doc in query.docs) {
      final period = doc['period'];
      if (!doc.data().containsKey('timestamp')) {
        print('Firestore nutrition log sem timestamp: ${doc.data()}');
        continue;
      }
      final ts = doc['timestamp'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        if (dt.isAfter(startOfDay) &&
            dt.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
          if (confirmed.containsKey(period) && doc['status'] == 'confirmed') {
            confirmed[period] = true;
          }
        }
      }
    }
    setState(() {
      _mealConfirmed.clear();
      _mealConfirmed.addAll(confirmed);
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
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.grey.shade300,
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
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
                "Today's Meals",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Confirm your meals for a healthy day.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3, // 3 columns for the cards
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMealCard(
                    context,
                    icon: Icons.bakery_dining,
                    title: 'Breakfast',
                    time: 'until 10:00 am',
                  ),
                  _buildMealCard(
                    context,
                    icon: Icons.lunch_dining,
                    title: 'Lunch',
                    time: 'until 14:00 pm',
                  ),
                  _buildMealCard(
                    context,
                    icon: Icons.dinner_dining,
                    title: 'Dinner',
                    time: 'until 08:00 pm',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String time,
  }) {
    final isConfirmed = _mealConfirmed[title] ?? false;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.green.shade100,
        ), // Lighter green for the border
      ),
      color: Colors.green.shade50, // Lighter green for the background
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 64, color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Flexible(
              child:
                  isConfirmed
                      ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 40,
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed:
                                _isWithinMealTime(title)
                                    ? () async {
                                      if (_mealConfirmed[title] == true) return;
                                      setState(() {
                                        _mealConfirmed[title] = true;
                                      });
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        await FirebaseFirestore.instance
                                            .collection('nutrition_logs')
                                            .add({
                                              'patient_id': user.uid,
                                              'period': title,
                                              'timestamp': Timestamp.now(),
                                              'status': 'confirmed',
                                            });
                                        final userDoc =
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .get();
                                        final patientName =
                                            userDoc.data()?['name'] ??
                                            'Older adult';
                                        final relationSnapshot =
                                            await FirebaseFirestore.instance
                                                .collection(
                                                  'caregiver_patients',
                                                )
                                                .where(
                                                  'patient_id',
                                                  isEqualTo: user.uid,
                                                )
                                                .get();
                                        final caregiverIds =
                                            relationSnapshot.docs
                                                .map(
                                                  (doc) => doc['caregiver_id'],
                                                )
                                                .toSet();
                                        for (var caregiverId in caregiverIds) {
                                          await NotificationService()
                                              .createNotification(
                                                caregiverId: caregiverId,
                                                patientId: user.uid,
                                                message:
                                                    '$patientName confirmed $title',
                                                type: 'nutrition',
                                              );
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '$title confirmed and saved!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (!_isWithinMealTime(title))
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Outside the confirmation time window',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
