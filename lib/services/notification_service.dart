import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createNotification({
    required String caregiverId,
    required String patientId,
    required String message,
    required String type,
  }) async {
    await _db.collection('notifications').add({
      'caregiver_id': caregiverId,
      'patient_id': patientId,
      'message': message,
      'type': type,
      'timestamp': Timestamp.now(),
      'read': false,
    });
  }
}
