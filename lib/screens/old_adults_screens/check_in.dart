import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  User? user;
  String olderAdultId = '';
  final Map<String, bool> _checkInConfirmed = {
    'Morning': false,
    'Evening': false,
  };

  int _currentHour = 0;
  int _currentMinute = 0;
  int _currentSecond = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    olderAdultId = user?.uid ?? '';
    _checkTimeEligibility();
    final now = DateTime.now();
    _currentHour = now.hour;
    _currentMinute = now.minute;
    _currentSecond = now.second;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentHour = now.hour;
        _currentMinute = now.minute;
        _currentSecond = now.second;
        _checkTimeEligibility();
      });
    });
  }

  void _checkTimeEligibility() {
    final now = DateTime.now();
    final hour = now.hour;

    _checkInConfirmed['Morning'] = hour >= 8 && hour < 10;

    _checkInConfirmed['Evening'] = hour >= 18 && hour < 20;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
            const Text(
              'Check-In',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirm your well-being twice a day.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCheckInCard(
                    context: context,
                    timeOfDay: 'Morning',
                    time: 'By 10:00 am',
                    icon: Icons.wb_sunny,
                    iconColor: Colors.amber,
                    backgroundColor: Colors.yellow.shade100,
                  ),
                  _buildCheckInCard(
                    context: context,
                    timeOfDay: 'Evening',
                    time: 'By 10:00 pm',
                    icon: Icons.nightlight_round,
                    iconColor: Colors.indigo,
                    backgroundColor: Colors.indigo.shade100,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInCard({
    required BuildContext context,
    required String timeOfDay,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    final isConfirmed = _checkInConfirmed[timeOfDay] ?? false;

    // Determine if the button should be enabled
    bool isButtonEnabled = false;
    int unlockHour = 0;
    int lockHour = 0;
    if (timeOfDay == 'Morning') {
      unlockHour = 8;
      lockHour = 10;
      isButtonEnabled = _currentHour >= unlockHour && _currentHour < lockHour;
    } else if (timeOfDay == 'Evening') {
      unlockHour = 18;
      lockHour = 20;
      isButtonEnabled = _currentHour >= unlockHour && _currentHour < lockHour;
    }

    // Calculate countdown
    String countdownText = '';
    if (!isButtonEnabled && !isConfirmed) {
      final now = DateTime.now();
      DateTime unlockTime;
      if (timeOfDay == 'Morning') {
        if (now.hour >= lockHour) {
          unlockTime = DateTime(
            now.year,
            now.month,
            now.day + 1,
            unlockHour,
            0,
            0,
          );
        } else if (now.hour < unlockHour) {
          unlockTime = DateTime(now.year, now.month, now.day, unlockHour, 0, 0);
        } else {
          unlockTime = now;
        }
      } else {
        if (now.hour >= lockHour) {
          unlockTime = DateTime(
            now.year,
            now.month,
            now.day + 1,
            unlockHour,
            0,
            0,
          );
        } else if (now.hour < unlockHour) {
          unlockTime = DateTime(now.year, now.month, now.day, unlockHour, 0, 0);
        } else {
          unlockTime = now;
        }
      }
      final diff = unlockTime.difference(now);
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      countdownText = "Unlocks in $hours:$minutes:$seconds";
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 70, color: iconColor),
            const SizedBox(height: 20),
            Text(
              timeOfDay,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              time,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child:
                  isConfirmed
                      ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      )
                      : ElevatedButton(
                        onPressed:
                            isButtonEnabled
                                ? () async {
                                  if (_checkInConfirmed[timeOfDay] == true)
                                    return;

                                  setState(() {
                                    _checkInConfirmed[timeOfDay] = true;
                                  });

                                  final uid = user?.uid ?? '';
                                  await FirebaseFirestore.instance
                                      .collection('checkin_logs')
                                      .add({
                                    'patient_id': uid,
                                    'period': timeOfDay,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });

                                  final userDoc =
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .get();
                                  final patientName =
                                      userDoc.data()?['name'] ?? 'Older adult';

                                  final caregiversSnapshot =
                                      await FirebaseFirestore.instance
                                          .collection('caregiver_patients')
                                          .where('patient_id', isEqualTo: uid)
                                          .get();

                                  final caregiverIds =
                                      caregiversSnapshot.docs
                                          .map((doc) => doc['caregiver_id'])
                                          .toSet();

                                  for (final caregiverId in caregiverIds) {
                                    await NotificationService().createNotification(
                                      caregiverId: caregiverId,
                                      patientId: uid,
                                      message:
                                          '$patientName confirmed $timeOfDay check-in',
                                      type: 'check_in',
                                    );
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$timeOfDay Check-In Confirmed',
                                      ),
                                    ),
                                  );
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isButtonEnabled ? Colors.green : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Check-In',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
            ),
            // Countdown timer
            if (!isButtonEnabled && !isConfirmed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  countdownText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
