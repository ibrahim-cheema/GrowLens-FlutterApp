import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/disease_api_service.dart';
import '../services/history_service.dart';
import 'history_screen.dart';

class DiseaseDetectionScreen extends StatelessWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Detection'),
        centerTitle: true,
        backgroundColor: const Color(0xFF447804),
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
      body: const DiseaseDetectionContent(),
    );
  }
}

class DiseaseDetectionContent extends StatefulWidget {
  const DiseaseDetectionContent({super.key});

  @override
  State<DiseaseDetectionContent> createState() =>
      _DiseaseDetectionContentState();
}

class _DiseaseDetectionContentState extends State<DiseaseDetectionContent> {
  static const Map<String, List<String>> _supportedClassesByPlant = {
    'Aloe': [
      'Anthracnose',
      'Leaf Spot',
      'Rust',
      'Sunburn',
      'Healthy',
    ],
    'Cactus': [
      'Dactylopius Opuntia',
      'Healthy',
    ],
    'Money Plant': [
      'Bacterial Wilt',
      'Manganese Toxicity',
      'Healthy',
    ],
    'Snake Plant': [
      'Anthracnose',
      'Leaf Withering',
      'Healthy',
    ],
    'Spider Plant': [
      'Fungal Leaf Spot',
      'Leaf Tip Necrosis',
      'Healthy',
    ],
  };

  final List<XFile?> _selectedImages = [null, null, null];
  final List<Uint8List?> _imageBytes = [null, null, null];
  bool _isAnalyzing = false;
  final ImagePicker _imagePicker = ImagePicker();
  final DiseaseApiService _apiService = DiseaseApiService();
  int _currentAngle = 0; // 0: Whole plant, 1: Affected leaf, 2: Close-up

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Instructions Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8FB25C), Color(0xFF447804)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.health_and_safety,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Capture 3 Angles for Best Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Multi-angle analysis increases disease identification accuracy by 40%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Scope of Detection Notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE6BC)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFF346E05),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scope of Detection',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF243C07),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model is optimized for selected indoor plants and disease conditions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TextButton.icon(
                        onPressed: _showSupportedClassesSheet,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF2F6806),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text(
                          'View Supported Classes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Angle Selection Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAngleTab(0, 'Habitat View', Icons.landscape),
                _buildAngleTab(1, 'Pest Close-up', Icons.center_focus_strong),
                _buildAngleTab(2, 'Damage View', Icons.warning),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current Angle Preview
          Column(
            children: [
              Text(
                _getAngleName(_currentAngle),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243C07),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getAngleDescription(_currentAngle),
                style: const TextStyle(
                  color: Color(0xFF346E05),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _selectedImages[_currentAngle] == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getAngleIcon(_currentAngle),
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Capture ${_getAngleName(_currentAngle)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _imageBytes[_currentAngle] != null
                            ? Image.memory(
                                _imageBytes[_currentAngle]!,
                                fit: BoxFit.cover,
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Capture Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () =>
                      _pickImageForCurrentAngle(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8FB25C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () =>
                      _pickImageForCurrentAngle(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Indicators
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Capture Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF243C07),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProgressStep(0, 'Habitat'),
                    Container(
                      height: 2,
                      width: 40,
                      color: _selectedImages[0] != null
                          ? const Color(0xFF8FB25C)
                          : Colors.grey[300],
                    ),
                    _buildProgressStep(1, 'Pest'),
                    Container(
                      height: 2,
                      width: 40,
                      color: _selectedImages[1] != null
                          ? const Color(0xFF8FB25C)
                          : Colors.grey[300],
                    ),
                    _buildProgressStep(2, 'Damage'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Analyze Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canAnalyze()
                  ? (_isAnalyzing ? null : _analyzeDisease)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canAnalyze() ? const Color(0xFF447804) : Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _canAnalyze()
                          ? 'Analyze All 3 Angles'
                          : 'Complete all 3 captures',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          // Analysis Status
          if (_isAnalyzing)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF8FB25C)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Analyzing disease images...',
                    style: TextStyle(
                      color: Color(0xFF346E05),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connecting to Disease Detection Server...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAngleTab(int angleIndex, String title, IconData icon) {
    final bool isSelected = _currentAngle == angleIndex;
    final bool hasImage = _selectedImages[angleIndex] != null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentAngle = angleIndex;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8FB25C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8FB25C) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF8FB25C),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF243C07),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEFB8F),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(int angleIndex, String label) {
    final bool hasImage = _selectedImages[angleIndex] != null;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: hasImage ? const Color(0xFF8FB25C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasImage ? const Color(0xFF8FB25C) : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Center(
            child: hasImage
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${angleIndex + 1}',
                    style: const TextStyle(
                      color: Color(0xFF346E05),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: hasImage ? const Color(0xFF243C07) : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getAngleName(int angle) {
    switch (angle) {
      case 0:
        return 'Habitat View';
      case 1:
        return 'Pest Close-up';
      case 2:
        return 'Damage View';
      default:
        return '';
    }
  }

  String _getAngleDescription(int angle) {
    switch (angle) {
      case 0:
        return 'Overall plant/surrounding area';
      case 1:
        return 'Clear close-up of the pest';
      case 2:
        return 'Damaged leaves or affected area';
      default:
        return '';
    }
  }

  IconData _getAngleIcon(int angle) {
    switch (angle) {
      case 0:
        return Icons.landscape;
      case 1:
        return Icons.center_focus_strong;
      case 2:
        return Icons.warning;
      default:
        return Icons.photo_camera;
    }
  }

  Future<void> _pickImageForCurrentAngle(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImages[_currentAngle] = image;
          _imageBytes[_currentAngle] = bytes;

          // Auto-advance to next incomplete angle
          for (int i = _currentAngle + 1; i < 3; i++) {
            if (_selectedImages[i] == null) {
              _currentAngle = i;
              break;
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _canAnalyze() {
    return _selectedImages.every((image) => image != null) &&
        _imageBytes.every((image) => image != null);
  }

  Future<void> _analyzeDisease() async {
    if (!_canAnalyze()) return;

    final imageBytes = _imageBytes.whereType<Uint8List>().toList();
    final filenames =
        _selectedImages.whereType<XFile>().map((e) => e.name).toList();

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result =
          await _apiService.predictDiseaseBatch(imageBytes, filenames);

      if (!mounted) return;
      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> json) {
    final report = json['report']?.toString().trim() ?? '';
    final filename = json['filename']?.toString() ?? 'uploaded_images';
    final status = json['status']?.toString().toUpperCase() ?? 'SUCCESS';
    final diagnosisTitle =
        _extractDiagnosisTitle(report) ?? _deriveTitleFromFilename(filename);
    final capturedImageBase64 = _firstSelectedImageBase64();

    _saveDiseaseHistory(
      diagnosisTitle,
      report,
      filename,
      json['status']?.toString() ?? 'success',
      capturedImageBase64,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: Color(0xFF447804),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Disease Analysis Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF243C07),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildResultSection(
                  title: 'Diagnosis',
                  icon: Icons.medical_information_outlined,
                  child: Text(
                    diagnosisTitle.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF243C07),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildResultSection(
                  title: 'Metadata',
                  icon: Icons.info_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: $status',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'File: $filename',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildResultSection(
                  title: 'Expert Report',
                  icon: Icons.description_outlined,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.34,
                    ),
                    child: SingleChildScrollView(
                      child: _buildFormattedReport(report),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF447804),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close Analysis'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF346E05)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF346E05),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildFormattedReport(String report) {
    final String source = report.trim();
    if (source.isEmpty) {
      return Text(
        'No report was returned by the server.',
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      );
    }

    final List<Widget> blocks = [];
    final List<String> lines = source.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('###') ||
          line.startsWith('##') ||
          line.startsWith('#')) {
        final heading = line.replaceFirst(RegExp(r'^#+\s*'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              heading,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF243C07),
              ),
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('- ') || line.startsWith('* ')) {
        final bulletText = line.substring(2).trim();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: Color(0xFF447804),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInlineStyledText(
                    bulletText,
                    baseStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildInlineStyledText(
            line,
            baseStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _buildInlineStyledText(
    String text, {
    required TextStyle baseStyle,
  }) {
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    final List<InlineSpan> spans = [];
    int currentIndex = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(1) ?? '',
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: baseStyle,
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Failed'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String? _extractDiagnosisTitle(String report) {
    if (report.isEmpty) return null;

    final match = RegExp(r'\*\*([^*]+)\*\*').firstMatch(report);
    if (match == null) return null;

    return DiseaseApiService.getDisplayName(match.group(1)!.trim());
  }

  String _deriveTitleFromFilename(String filename) {
    final base = filename.split('.').first.trim();
    if (base.isEmpty) return 'Diagnosis Report';
    return DiseaseApiService.getDisplayName(base);
  }

  void _showSupportedClassesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6DD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.rule_folder_outlined,
                          color: Color(0xFF346E05),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Supported Plants & Conditions',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF243C07),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These classes are currently optimized by the disease model.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _supportedClassesByPlant.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry =
                            _supportedClassesByPlant.entries.elementAt(index);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAEF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2EACE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF243C07),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.value
                                    .map(
                                      (condition) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFFD7E2B7),
                                          ),
                                        ),
                                        child: Text(
                                          condition,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF447804),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
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

  Future<void> _saveDiseaseHistory(
    String diagnosisTitle,
    String report,
    String filename,
    String status,
    String? capturedImageBase64,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await HistoryService.saveDiseaseResult(user.uid, {
        'predicted_class': diagnosisTitle,
        'confidence': 'N/A',
        'report': report,
        'filename': filename,
        'status': status,
        'captured_image_base64': capturedImageBase64,
        'result_source': 'indoor_plant_doctor_api_files',
      });
    } catch (e) {
      debugPrint('Failed to save disease history: $e');
    }
  }

  String? _firstSelectedImageBase64() {
    for (final bytes in _imageBytes) {
      if (bytes != null && bytes.isNotEmpty) {
        return base64Encode(bytes);
      }
    }
    return null;
  }
}
