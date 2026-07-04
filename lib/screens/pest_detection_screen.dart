import 'package:flutter/material.dart';
import 'package:growlens/widgets/pest_detection_content.dart';
import 'history_screen.dart';

// Wrapper for backward compatibility
class PestDetectionScreen extends StatelessWidget {
  const PestDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pest Detection'),
        centerTitle: true,
        backgroundColor: const Color(0xFF8FB25C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: const PestDetectionContent(),
    );
  }
}