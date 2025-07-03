import 'package:flutter/material.dart';

class LayoutWrapper extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar; // Add an optional appBar parameter

  const LayoutWrapper({super.key, required this.body, this.appBar}); // Update constructor

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar, // Use the appBar if provided
      backgroundColor: const Color(0xFFFAFEFF),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: body, // The main content of the page
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
