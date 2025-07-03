import 'package:flutter/material.dart';
import '../../widgets/layout_wrapper.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutWrapper(
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
                Navigator.pushNamed(context, '/home_screen');
              },
              child: const Text(
                'Home',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/about_us');
              },
              child: const Text(
                'About Us',
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
            icon: const Icon(Icons.account_circle, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/profile'); // Navigate to profile
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/ipb.jpg',
                            fit: BoxFit.cover,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CareConnect: Integrated Home Care Monitoring Platform',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'CareConnect is an innovative mobile solution for efficient home care management. It allows nurses, caregivers, and family members to track health metrics, set reminders, and receive alerts if an old adult person fails to confirm well-being. Features include secure authentication, profile management with QR codes, family-based access control, and offline support. With an intuitive interface for seniors and advanced tools for professionals, CareConnect enhances safety, communication, and care quality while ensuring data security and compliance.',
                                  style: TextStyle(fontSize: 16, color: Colors.black54),
                                  textAlign: TextAlign.justify,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Team Members:',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    _TeamMemberCard(
                                      name: 'João Costa',
                                      id: 'a44582',
                                    ),
                                    _TeamMemberCard(
                                      name: 'Miguel Correia',
                                      id: 'a48548',
                                    ),
                                    _TeamMemberCard(
                                      name: 'Fernando José',
                                      id: 'a44841',
                                    ),
                                    _TeamMemberCard(
                                      name: 'Rui Silva',
                                      id: 'a56097',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'University:',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Instituto Politécnico de Bragança (IPB)',
                                  style: TextStyle(fontSize: 16, color: Colors.black87),
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/ipb.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CareConnect: Integrated Home Care Monitoring Platform',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'CareConnect is an innovative mobile solution for efficient home care management. It allows nurses, caregivers, and family members to track health metrics, set reminders, and receive alerts if an old adult person fails to confirm well-being. Features include secure authentication, profile management with QR codes, family-based access control, and offline support. With an intuitive interface for seniors and advanced tools for professionals, CareConnect enhances safety, communication, and care quality while ensuring data security and compliance.',
                                style: TextStyle(fontSize: 16, color: Colors.black54),
                                textAlign: TextAlign.justify,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Team Members:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  _TeamMemberCard(
                                    name: 'João Costa',
                                    id: 'a44582',
                                  ),
                                  _TeamMemberCard(
                                    name: 'Miguel Correia',
                                    id: 'a48548',
                                  ),
                                  _TeamMemberCard(
                                    name: 'Fernando José',
                                    id: 'a44841',
                                  ),
                                  _TeamMemberCard(
                                    name: 'Rui Silva',
                                    id: 'a56097',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'University:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Instituto Politécnico de Bragança (IPB)',
                                style: TextStyle(fontSize: 16, color: Colors.black87),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String name;
  final String id;

  const _TeamMemberCard({required this.name, required this.id});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 150,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle,
              size: 50,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            Text(
              id,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
