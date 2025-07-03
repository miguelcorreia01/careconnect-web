import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //  Create Older Adult
  Future<void> createOlderAdult({
    required String name,
    required String dob,
    required String caregiverId,
    required String familyId,
  }) async {
    await _db.collection('olderAdults').add({
      'name': name,
      'dob': dob,
      'caregiverId': caregiverId,
      'familyId': familyId,
      'active': true,
      'createdAt': Timestamp.now(),
    });
  }

  // Create Reminder for Older Adult
  Future<void> createReminder({
    required String olderAdultId,
    required String label,
    required String time,
    required String createdBy,
  }) async {
    await _db.collection('reminders').add({
      'olderAdultId': olderAdultId,
      'label': label,
      'time': time,
      'createdBy': createdBy,
      'createdAt': Timestamp.now(),
    });
  }

  //  Confirm Reminder 
  Future<void> confirmReminder({
    required String reminderId,
    required String olderAdultId,
    required String confirmedBy,
  }) async {
    await _db.collection('confirmations').add({
      'reminderId': reminderId,
      'olderAdultId': olderAdultId,
      'confirmedBy': confirmedBy,
      'confirmedAt': Timestamp.now(),
    });
  }

// Add a check-in
Future<void> addCheckIn({
  required String olderAdultId,
  required String timeOfDay, // "Morning" or "Evening"
}) async {
  final now = DateTime.now();
  final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  await _db.collection('checkIns').add({
    'olderAdultId': olderAdultId,
    'timeOfDay': timeOfDay,
    'checkedInAt': Timestamp.now(),
    'date': dateStr,
  });
}

// Get today's check-ins for an older adult
Future<List<Map<String, dynamic>>> getTodaysCheckIns(String olderAdultId) async {
  final now = DateTime.now();
  final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  final snapshot = await _db
      .collection('checkIns')
      .where('olderAdultId', isEqualTo: olderAdultId)
      .where('date', isEqualTo: dateStr)
      .get();
  return snapshot.docs.map((doc) => doc.data()).toList();
}
  // Get all reminders for an older adult
  Future<List<Map<String, dynamic>>> getReminders(String olderAdultId) async {
    final snapshot = await _db
        .collection('reminders')
        .where('olderAdultId', isEqualTo: olderAdultId)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get all older adults for a caregiver
  Future<List<Map<String, dynamic>>> getOlderAdultsByCaregiver(String caregiverId) async {
    final snapshot = await _db
        .collection('olderAdults')
        .where('caregiverId', isEqualTo: caregiverId)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get all older adults for a family
  Future<List<Map<String, dynamic>>> getOlderAdultsByFamily(String familyId) async {
    final snapshot = await _db
        .collection('olderAdults')
        .where('familyId', isEqualTo: familyId)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get all caregivers for an older adult
  Future<List<Map<String, dynamic>>> getCaregiversByOlderAdult(String olderAdultId    ) async {
    final snapshot = await _db
        .collection('caregivers')
        .where('olderAdultId', isEqualTo: olderAdultId)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get all families for an older adult
  Future<List<Map<String, dynamic>>> getFamiliesByOlderAdult(String olderAdultId) async {
    final snapshot = await _db
        .collection('families')
        .where('olderAdultId', isEqualTo: olderAdultId)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }   

  

}
