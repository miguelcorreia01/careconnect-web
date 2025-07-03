import 'package:flutter/material.dart';
import '../../widgets/layout_wrapper.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            // Add styled buttons for Sign In and Register in the header
            ElevatedButton.icon(
              icon: const Icon(Icons.login, size: 20, color: Colors.white),
              label: const Text('Sign In', style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1, size: 20, color: Colors.white),
              label: const Text('Register', style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
            ),
          ],
        ),
      ),
      body: LayoutWrapper(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            return Column(
              children: [
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Welcome to CareConnect',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'CareConnect is your innovative solution for efficient home care management. '
                                      'Track health metrics, set reminders, and ensure the safety of your loved ones.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    const Text(
                                      'Why Choose Us?',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Column(
                                      children: const [
                                        _FeatureRow(
                                          icon: Icons.check_circle,
                                          text: 'Medication reminders and health tracking.',
                                        ),
                                        SizedBox(height: 8),
                                        _FeatureRow(
                                          icon: Icons.check_circle,
                                          text: 'Secure communication and emergency alerts.',
                                        ),
                                        SizedBox(height: 8),
                                        _FeatureRow(
                                          icon: Icons.check_circle,
                                          text: 'Family-based access control and reports.',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    // Remove the Row with Sign In and Register buttons and the "Need help?" row
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 600,
                                width: 800,
                                child: Image.asset(
                                  'assets/images/home-image.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 400,
                                width: 600,
                                child: Image.asset(
                                  'assets/images/home-image.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Welcome to CareConnect',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'CareConnect is your innovative solution for efficient home care management. '
                                      'Track health metrics, set reminders, and ensure the safety of your loved ones.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Remove the Column with Sign In and Register buttons and the "Need help?" row
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFAFEFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Center(
                    child: Text(
                      '© 2025 CareConnect. All rights reserved',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to CareConnect'),
        backgroundColor: const Color(0xFFD9D9D9),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to CareConnect',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Login'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
