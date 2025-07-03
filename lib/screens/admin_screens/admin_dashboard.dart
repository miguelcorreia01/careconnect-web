import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart' as pie_chart_package;
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalUsers = 0;
  int oldAdults = 0;
  int caregivers = 0;
  int familyMembers = 0;
  int admins = 0; // Add admin count
  int otherUsers = 0; // Optional: for unknown roles
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
  }

  Future<void> _fetchUserStats() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    int old = 0, care = 0, fam = 0, adm = 0, other = 0;
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final roleRaw = data['role'];
      final role = roleRaw != null ? roleRaw.toString().toLowerCase().trim() : '';
      // Match roles as set in register.dart
      if (role == 'older_adult') {
        old++;
      } else if (role == 'caregiver') {
        care++;
      } else if (role == 'family') {
        fam++;
      } else if (role == 'admin') {
        adm++;
      } else {
        other++;
      }
    }
    setState(() {
      totalUsers = usersSnapshot.size;
      oldAdults = old;
      caregivers = care;
      familyMembers = fam;
      admins = adm;
      otherUsers = other; // Optional
      isLoading = false;
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
            const Text(
              'Care',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Text(
              'Connect',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text('Dashboard', style: TextStyle(color: Colors.blue)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/users_list');
                // Quando voltar da lista de usuários, atualiza os stats
                _fetchUserStats();
              },
              child: const Text('Users List', style: TextStyle(color: Colors.black)),
            ),
            const Spacer(),
          ],
        ),
        actions: [
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildStatCard('Total Users', '$totalUsers', Icons.people, Colors.teal.shade100),
                      _buildStatCard('Old Adults', '$oldAdults', Icons.person, Colors.green.shade100),
                      _buildStatCard('Caregivers', '$caregivers', Icons.health_and_safety, Colors.blue.shade100),
                      _buildStatCard('Family Members', '$familyMembers', Icons.family_restroom, Colors.lightBlue.shade100),
                      _buildStatCard('Admins', '$admins', Icons.admin_panel_settings, Colors.red.shade100), // New card
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildUserGrowthLineChart(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildUserGrowthCard(context),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color backgroundColor) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.black54),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: MediaQuery.of(context).size.width / 5.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• 4h ago Family Member account created'),
              Text('• 6h ago Old Adult account created'),
              Text('• 7h ago Old Adult account deleted'),
              Text('• 12h ago Family Member account created'),
              Text('• Yesterday Caregiver account created'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserGrowthCard(BuildContext context) {
    final dataMap = {
      "Old Adults": oldAdults.toDouble(),
      "Caregivers": caregivers.toDouble(),
      "Family Members": familyMembers.toDouble(),
      "Admins": admins.toDouble(), // Add admins to pie chart
    };

    final colorList = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red.shade300, // Use a distinct red for admins
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: MediaQuery.of(context).size.width / 5.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: pie_chart_package.PieChart(
                        dataMap: dataMap,
                        animationDuration: const Duration(milliseconds: 800),
                        chartLegendSpacing: 16,
                        chartRadius: MediaQuery.of(context).size.width / 7.0,
                        colorList: colorList,
                        chartType: pie_chart_package.ChartType.disc,
                        legendOptions: const pie_chart_package.LegendOptions(
                          showLegendsInRow: false,
                          legendPosition: pie_chart_package.LegendPosition.right,
                          showLegends: true,
                          legendShape: BoxShape.circle,
                          legendTextStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        chartValuesOptions: const pie_chart_package.ChartValuesOptions(
                          showChartValueBackground: true,
                          showChartValues: true,
                          showChartValuesInPercentage: true,
                          showChartValuesOutside: false,
                          decimalPlaces: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserGrowthLineChart(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').orderBy('created_at', descending: false).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No user data'));
        }

        // Count users per day
        final Map<DateTime, int> usersPerDay = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          DateTime? created;
          if (data['created_at'] is Timestamp) {
            created = (data['created_at'] as Timestamp).toDate();
          } else if (data['created_at'] is DateTime) {
            created = data['created_at'] as DateTime;
          } else if (data['created_at'] != null) {
            created = DateTime.tryParse(data['created_at'].toString());
          }
          if (created != null) {
            final day = DateTime(created.year, created.month, created.day);
            usersPerDay[day] = (usersPerDay[day] ?? 0) + 1;
          }
        }

        // Build cumulative growth data
        final sortedDays = usersPerDay.keys.toList()..sort();
        List<FlSpot> userGrowthData = [];
        int cumulative = 0;
        for (int i = 0; i < sortedDays.length; i++) {
          cumulative += usersPerDay[sortedDays[i]]!;
          userGrowthData.add(FlSpot(i.toDouble(), cumulative.toDouble()));
        }

        if (userGrowthData.isEmpty) {
          userGrowthData.add(const FlSpot(0, 0));
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: MediaQuery.of(context).size.width / 5.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Growth Over Time',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (() {
                                // Calculate a nice interval for Y axis (5, 10, 20, etc)
                                if (userGrowthData.isEmpty) return 1.0;
                                final maxY = userGrowthData.map((e) => e.y).fold<double>(0, (a, b) => a > b ? a : b);
                                if (maxY <= 10) return 1.0;
                                if (maxY <= 50) return 5.0;
                                if (maxY <= 100) return 10.0;
                                if (maxY <= 200) return 20.0;
                                if (maxY <= 500) return 50.0;
                                return 100.0;
                              })(),
                              getTitlesWidget: (value, meta) {
                                return Text('${value.toInt()}', style: const TextStyle(fontSize: 12));
                              },
                              reservedSize: 40,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                // Show only a few labels to avoid overlap
                                if (idx >= 0 && idx < sortedDays.length) {
                                  int n = sortedDays.length <= 7 ? 1 : (sortedDays.length ~/ 6).clamp(1, sortedDays.length);
                                  if (idx == 0 || idx == sortedDays.length - 1 || idx % n == 0) {
                                    final d = sortedDays[idx];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 12)),
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: 36,
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: userGrowthData,
                            isCurved: true,
                            barWidth: 4,
                            color: Colors.blue,
                            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
