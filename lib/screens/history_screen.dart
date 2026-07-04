import 'package:flutter/material.dart';
import '../services/history_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _pestHistoryFuture;
  late Future<List<Map<String, dynamic>>> _diseaseHistoryFuture;
  late Future<List<Map<String, dynamic>>> _gardenHistoryFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _pestHistoryFuture = HistoryService.getHistory(user.uid);
        _diseaseHistoryFuture = HistoryService.getDiseaseHistory(user.uid);
        _gardenHistoryFuture = HistoryService.getGardenDesignHistory(user.uid);
      });
    } else {
      setState(() {
        _pestHistoryFuture = Future.value([]);
        _diseaseHistoryFuture = Future.value([]);
        _gardenHistoryFuture = Future.value([]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Analysis History'),
        centerTitle: true,
        backgroundColor: const Color(0xFF8FB25C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pest Detection'),
            Tab(text: 'Disease Detection'),
            Tab(text: 'Garden Analysis'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _showClearHistoryDialog();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(_pestHistoryFuture),
          _buildHistoryTab(_diseaseHistoryFuture),
          _buildGardenHistoryTab(_gardenHistoryFuture),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Future<List<Map<String, dynamic>>> historyFuture) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No history yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: history.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = history[index];
            return _buildHistoryCard(item);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    String predictionName =
        item['predicted_class']?.toString().trim().isNotEmpty == true
            ? item['predicted_class'].toString().trim()
            : 'Diagnosis Report';
    String confidence = item['confidence']?.toString().trim() ?? '';
    String report = item['report']?.toString().trim() ?? '';
    String timestamp = item['timestamp']?.toString() ?? '';
    String? overlayDataUrl = item['overlay_image']?.toString();
    String? overlayImageUrl = item['overlay_image_url']?.toString();
    String? imageUrl = item['image_url']?.toString();
    String? capturedImageBase64 = item['captured_image_base64']?.toString();

    DateTime? date;
    if (timestamp.isNotEmpty) {
      date = DateTime.tryParse(timestamp);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: _buildHistoryImage(
                  overlayDataUrl: overlayDataUrl,
                  overlayImageUrl: overlayImageUrl,
                  imageUrl: imageUrl,
                  capturedImageBase64: capturedImageBase64,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    predictionName.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF243C07),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (confidence.isNotEmpty && confidence.toUpperCase() != 'N/A')
                    Text(
                      'Confidence: $confidence',
                      style: const TextStyle(
                        color: Color(0xFF447804),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (report.isNotEmpty)
                    Text(
                      _compactReport(report),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (date != null)
                    Text(
                      DateFormat('MMM d, yyyy - h:mm a').format(date),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGardenHistoryTab(Future<List<Map<String, dynamic>>> historyFuture) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No garden analysis history yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: history.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return _buildGardenHistoryCard(history[index]);
          },
        );
      },
    );
  }

  Widget _buildGardenHistoryCard(Map<String, dynamic> item) {
    final city = (item['city']?.toString().trim().isNotEmpty == true)
        ? item['city'].toString().trim()
        : 'Faisalabad';
    final style = (item['style']?.toString().trim().isNotEmpty == true)
        ? item['style'].toString().trim()
        : 'Garden Style';
    final analysis = item['ai_analysis']?.toString().trim() ?? '';
    final timestamp = item['timestamp']?.toString() ?? '';
    final base64 = item['designed_image_base64']?.toString();

    DateTime? date;
    if (timestamp.isNotEmpty) {
      date = DateTime.tryParse(timestamp);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: analysis.isEmpty
          ? null
          : () {
              _showGardenAnalysisDetails(
                city: city,
                style: style,
                analysis: analysis,
                date: date,
              );
            },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 88,
                  height: 88,
                  color: Colors.grey[200],
                  child: _buildGardenImage(base64),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$city • $style',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF243C07),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (analysis.isNotEmpty)
                      Text(
                        _compactReport(analysis),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    if (date != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM d, yyyy - h:mm a').format(date),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGardenImage(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) {
      return const Icon(Icons.image_not_supported, color: Colors.grey);
    }

    try {
      return Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.cover,
      );
    } catch (_) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }

  void _showGardenAnalysisDetails({
    required String city,
    required String style,
    required String analysis,
    required DateTime? date,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Garden Analysis',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF243C07),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetaPill(Icons.location_on_outlined, city),
                      _buildMetaPill(Icons.style_outlined, style),
                      if (date != null)
                        _buildMetaPill(
                          Icons.schedule_outlined,
                          DateFormat('MMM d, yyyy').format(date),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildAnalysisBody(analysis),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8EA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE9C4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF447804)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF243C07),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisBody(String rawText) {
    final lines = rawText.replaceAll('\r\n', '\n').trim().split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (heading != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              heading.group(2)!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A4E0D),
              ),
            ),
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^(?:[-*]|\d+[.)])\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF447804),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bullet.group(1)!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.42,
                      color: Color(0xFF2D3A21),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.42,
              color: Color(0xFF2D3A21),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildBase64Image(String dataUrl) {
    try {
      String base64String = dataUrl;
      if (dataUrl.contains(',')) {
        base64String = dataUrl.split(',')[1];
      }
      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    } catch (e) {
      return const Icon(Icons.error);
    }
  }

  String _compactReport(String report) {
    return report.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Widget _buildHistoryImage({
    required String? overlayDataUrl,
    required String? overlayImageUrl,
    required String? imageUrl,
    required String? capturedImageBase64,
  }) {
    if (overlayDataUrl != null && overlayDataUrl.isNotEmpty) {
      return _buildBase64Image(overlayDataUrl);
    }

    if (capturedImageBase64 != null && capturedImageBase64.isNotEmpty) {
      return _buildBase64Image(capturedImageBase64);
    }

    final networkUrl = (overlayImageUrl != null && overlayImageUrl.isNotEmpty)
        ? overlayImageUrl
        : ((imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null);

    if (networkUrl != null) {
      return Image.network(
        networkUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return const Icon(Icons.image_not_supported, color: Colors.grey);
  }

  void _showClearHistoryDialog() {
    const tabNames = ['pest', 'disease', 'garden analysis'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: Text('Clear ${tabNames[_tabController.index]} history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                if (_tabController.index == 0) {
                  await HistoryService.clearHistory(user.uid);
                } else if (_tabController.index == 1) {
                  await HistoryService.clearDiseaseHistory(user.uid);
                } else {
                  await HistoryService.clearGardenDesignHistory(user.uid);
                }
                _loadHistory();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
