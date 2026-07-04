import 'package:flutter/material.dart';
import 'package:growlens/widgets/pest_detection_content.dart';
import 'package:growlens/screens/disease_detection_screen.dart' as disease;
import 'package:growlens/screens/history_screen.dart';

class ScanScreen extends StatefulWidget {
  final int initialIndex;
  final bool showAppBar;
  
  const ScanScreen({
    super.key, 
    this.initialIndex = 0,
    this.showAppBar = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  PreferredSizeWidget _buildScanAppBar() {
    return AppBar(
      title: const Text('Scan Plant'),
      centerTitle: true,
      backgroundColor: const Color(0xFF447804),
      foregroundColor: Colors.white,
      bottom: const TabBar(
        indicatorColor: Color(0xFFEEFB8F),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        tabs: [
          Tab(
            icon: Icon(Icons.health_and_safety),
            text: "Disease",
          ),
          Tab(
            icon: Icon(Icons.bug_report),
            text: "Pest",
          ),
        ],
      ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        appBar: widget.showAppBar ? _buildScanAppBar() : null,
        body: widget.showAppBar
            ? TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const disease.DiseaseDetectionContent(),
                  const PestDetectionContent(),
                ],
              )
            : Column(
                children: const [
                  Material(
                    color: Color(0xFF447804),
                    child: SafeArea(
                      bottom: false,
                      child: TabBar(
                        indicatorColor: Color(0xFFEEFB8F),
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold),
                        tabs: [
                          Tab(
                            icon: Icon(Icons.health_and_safety),
                            text: "Disease",
                          ),
                          Tab(
                            icon: Icon(Icons.bug_report),
                            text: "Pest",
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        disease.DiseaseDetectionContent(),
                        PestDetectionContent(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
