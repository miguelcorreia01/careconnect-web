import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: firebaseUser.email)
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final firestoreUid = userDoc.docs.first['uid'];
        // Removido print de debug
        setState(() {
          _userId = firestoreUid;
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    if (_userId == null) return const Stream.empty();
    // Removido print de debug
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('patient_id', isEqualTo: _userId)
        // .orderBy('date') // REMOVIDO temporariamente
        .snapshots();
  }

  Future<void> _addTask({
    required String name,
    required String description,
    required DateTime dateTime,
  }) async {
    await FirebaseFirestore.instance.collection('tasks').add({
      'name': name,
      'description': description,
      'date': Timestamp.fromDate(dateTime),
      'patient_id': _userId,
      'status': 'pending',
    });
  }

  Future<void> _deleteTask(String docId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(docId).delete();
  }

  Future<void> _updateTaskStatus(String docId, bool completed) async {
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(docId)
        .update({'status': completed ? 'completed' : 'pending'});
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
              onPressed: () => Navigator.pushNamed(context, '/old_adult_dashboard'),
              child: const Text('Dashboard', style: TextStyle(color: Colors.blue)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/manage_caregivers'),
              child: const Text('Caregivers', style: TextStyle(color: Colors.black)),
            ),
            const Spacer(),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications, color: Colors.black), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.emergency, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Column(
                    children: const [
                      Icon(Icons.emergency, size: 48, color: Colors.red),
                      SizedBox(height: 8),
                      Text('Activate Emergency', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: const Text(
                    'Are you sure you want to activate the emergency button?',
                    textAlign: TextAlign.center,
                  ),
                  actionsAlignment: MainAxisAlignment.spaceEvenly,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.account_circle, color: Colors.black), onPressed: () => Navigator.pushNamed(context, '/profile')),
          IconButton(icon: const Icon(Icons.logout, color: Colors.black), onPressed: () => Navigator.pushNamed(context, '/home_screen')),
        ],
      ),
      body: Container(
        color: const Color(0xFFF7FAFC),
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título e subtítulo centralizados como em check_in.dart
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Your Tasks',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Manage and complete your daily tasks here.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _userId == null
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _taskStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No tasks found.',
                                    style: TextStyle(fontSize: 22, color: Colors.black54, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }

                              final tasks = snapshot.data!.docs;

                              return ListView.separated(
                                itemCount: tasks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final doc = tasks[index];
                                  final task = doc.data();
                                  final completed = (task['status'] ?? '') == 'completed';

                                  return Material(
                                    color: completed ? const Color(0xFFE6F4EA) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    elevation: 2,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        _updateTaskStatus(doc.id, !completed);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(18.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Checkbox(
                                              value: completed,
                                              onChanged: (value) => _updateTaskStatus(doc.id, value!),
                                              activeColor: const Color(0xFF2F8369),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              side: const BorderSide(width: 2, color: Color(0xFF2F8369)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                                        color: completed ? Colors.green : Colors.grey,
                                                        size: 26,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                        child: Text(
                                                          task['name'] ?? '',
                                                          style: TextStyle(
                                                            fontSize: 22,
                                                            fontWeight: FontWeight.bold,
                                                            color: completed ? Colors.green.shade700 : Colors.black87,
                                                            decoration: completed ? TextDecoration.lineThrough : null,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.calendar_today, size: 20, color: Color(0xFF2F8369)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        () {
                                                          try {
                                                            final Timestamp ts = task['date'];
                                                            final DateTime dt = ts.toDate();
                                                            return DateFormat('dd MMM yyyy, HH:mm').format(dt);
                                                          } catch (e) {
                                                            return 'Invalid date';
                                                          }
                                                        }(),
                                                        style: const TextStyle(fontSize: 17, color: Colors.black87),
                                                      ),
                                                    ],
                                                  ),
                                                  if ((task['description'] ?? '').isNotEmpty) ...[
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Icon(Icons.notes, size: 20, color: Color(0xFF2F8369)),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            task['description'],
                                                            style: const TextStyle(fontSize: 17, color: Colors.black87),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                                              tooltip: 'Delete Task',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: const Text('Delete Task'),
                                                    content: const Text('Are you sure you want to delete this task?', textAlign: TextAlign.center),
                                                    actionsAlignment: MainAxisAlignment.spaceEvenly,
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: Colors.black,
                                                          backgroundColor: Colors.grey.shade300,
                                                        ),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () async {
                                                          await _deleteTask(doc.id);
                                                          Navigator.of(context).pop();
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Task deleted successfully!'),
                                                              backgroundColor: Colors.red,
                                                            ),
                                                          );
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        child: const Text('Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ));
                                  },
                                );
                            },
                          ),
                        ),
                ),
              ],
            ),
            // Novo botão flutuante grande e acessível
            Positioned(
              bottom: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: FloatingActionButton.extended(
                  onPressed: () => _showAddTaskDialog(context),
                  backgroundColor: const Color(0xFF2F8369),
                  icon: const Icon(Icons.add, size: 32, color: Colors.white),
                  label: const Text(
                    'Add Task',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white, // Texto branco
                    ),
                  ),
                  tooltip: 'Add a new task',
                  elevation: 6,
                  extendedPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
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
                                dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
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
                            await _addTask(
                              name: nameController.text.trim(),
                              description: descController.text.trim(),
                              dateTime: dateTime,
                            );
                            Navigator.of(context).pop();
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
      ),
    );
  }
}
