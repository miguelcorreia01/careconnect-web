import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
              onPressed: () => Navigator.pushNamed(context, '/family_dashboard'),
              child: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.blue, // Always blue to indicate the current page
                ),
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
            icon: const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/home_screen'); // Navigate to home screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reports Title
            const Text(
              'Reports',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Weekly/Monthly Buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Handle Weekly report logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Weekly',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    // Handle Monthly report logic
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Monthly',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating PDF...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Add logic to generate the PDF file here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Updated to a better color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Export PDF',
                    style: TextStyle(color: Colors.white), // White text for better contrast
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Report Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildReportCard(
                  icon: Icons.signal_cellular_alt,
                  title: 'Check-ins',
                  value: '24/28',
                  color: Colors.blue[100]!,
                ),
                _buildReportCard(
                  icon: Icons.medical_services_outlined,
                  title: 'Medication',
                  value: '32',
                  unit: 'times',
                  color: Colors.orange[100]!,
                ),
                _buildReportCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Emergencies',
                  value: '5',
                  unit: 'times',
                  color: Colors.yellow[100]!,
                ),
                _buildReportCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Hydration',
                  value: '72',
                  unit: 'times',
                  color: Colors.lightBlue[100]!,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Activity Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActivityRow('Check-ins', '24 times'),
                    const Divider(),
                    _buildActivityRow('Medication', '32 times'),
                    const Divider(),
                    _buildActivityRow('Emergencies', '5 times'),
                    const Divider(),
                    _buildActivityRow('Hydration', '72 times'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build the report summary cards
  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String value,
    String? unit,
    required Color color,
  }) {
    return Card(
      color: color,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (unit != null)
              Text(unit, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Helper function to build the activity rows
  Widget _buildActivityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
