import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:growlens/services/history_service.dart';

// Main Content Widget
class PestDetectionContent extends StatefulWidget {
  const PestDetectionContent({super.key});

  @override
  State<PestDetectionContent> createState() => _PestDetectionContentState();
}

class _PestDetectionContentState extends State<PestDetectionContent> {
  static const List<String> _supportedPestClasses = [
    'Ants',
    'Bees',
    'Beetle',
    'Caterpillar',
    'Earthworms',
    'Earwig',
    'Grasshopper',
    'Moth',
    'Slug',
    'Snail',
    'Wasp',
    'Weevil',
  ];

  final List<XFile?> _selectedImages = [null, null, null];
  final List<Uint8List?> _imageBytes = [null, null, null];
  bool _isAnalyzing = false;
  static const String _predictUrl = "http://51.21.82.112:8000/predict";
  final ImagePicker _imagePicker = ImagePicker();
  int _currentAngle = 0; // 0: Habitat, 1: Pest, 2: Damage

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
                  Icons.bug_report,
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
                  'Multi-angle analysis increases pest identification accuracy by 40%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _showSupportedPestsSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: Text(
                    'View Supported Pests',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
              onPressed:
                  _canAnalyze() ? (_isAnalyzing ? null : _analyzePests) : null,
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
                    'Analyzing pest images...',
                    style: TextStyle(
                      color: Color(0xFF346E05),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connecting to AWS Server...',
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
    bool isSelected = _currentAngle == angleIndex;
    bool hasImage = _selectedImages[angleIndex] != null;

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
    bool hasImage = _selectedImages[angleIndex] != null;

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
    return _selectedImages.every((image) => image != null);
  }

  Future<void> _analyzePests() async {
    if (!_canAnalyze()) return;

    setState(() {
      _isAnalyzing = true;
    });

    List<Map<String, dynamic>> results = [];

    try {
      var uri = Uri.parse(_predictUrl);

      // Send 3 separate requests
      for (int i = 0; i < 3; i++) {
        var request = http.MultipartRequest('POST', uri);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _imageBytes[i]!,
            filename: _selectedImages[i]!.name,
          ),
        );

        var response = await request.send();

        if (response.statusCode == 200) {
          var responseData = await response.stream.bytesToString();
          var json = jsonDecode(responseData);
          results.add(json);
        } else {
          debugPrint("Request $i failed with status ${response.statusCode}");
        }
      }

      if (results.isEmpty) {
        throw Exception("All requests failed");
      }

      // Find best result (highest confidence)
      Map<String, dynamic> bestResult = results[0];
      double maxConfidence = -1.0;

      for (var result in results) {
        var confVal = result['confidence'];
        double currentConf = 0.0;
        if (confVal is num) {
          currentConf = confVal.toDouble();
        } else if (confVal is String) {
          String cleanConf = confVal.replaceAll('%', '').trim();
          currentConf = double.tryParse(cleanConf) ?? 0.0;
        }

        if (currentConf > maxConfidence) {
          maxConfidence = currentConf;
          bestResult = result;
        }
      }

      if (bestResult.isNotEmpty && mounted) {
        _showRealResultDialog(bestResult);
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing images: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showRealResultDialog(Map<String, dynamic> json) {
    final detectedPest = _pickFirstText(
          json,
          const ['pest_name', 'label', 'detected_pest', 'predicted_class'],
        ) ??
        'Unknown';
    final confidence = _formatConfidence(
      _pickFirstValue(json, const ['confidence']),
    );
    final aiAdvice = _pickFirstText(
          json,
          const ['ai_advice', 'advice', 'report', 'analysis', 'recommendation'],
        ) ??
        'No AI-generated advice was returned.';
    final overlayDataUrl = _pickFirstText(
      json,
      const ['gradcam_base64', 'heatmap', 'overlay_image', 'gradcam'],
    );
    final imageUrl = _pickUrl(
      json,
      const ['image_url', 'input_image_url', 'original_image_url'],
    );
    final overlayImageUrl = _pickUrl(
      json,
      const ['overlay_image_url', 'result_image_url', 'heatmap_url'],
    );
    final capturedImageBase64 = _firstSelectedImageBase64();

    _savePestHistory(
      detectedPest,
      confidence,
      aiAdvice,
      imageUrl,
      overlayImageUrl,
      capturedImageBase64,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                        Icons.bug_report,
                        color: Color(0xFF447804),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Pest Analysis Report',
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
                  title: 'Detected Pest',
                  icon: Icons.pest_control_rodent_outlined,
                  child: Text(
                    detectedPest.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF243C07),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildResultSection(
                  title: 'Confidence Score',
                  icon: Icons.speed_outlined,
                  child: Text(
                    confidence,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF243C07),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildResultSection(
                  title: 'AI Generated Advice',
                  icon: Icons.auto_awesome_outlined,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.2,
                    ),
                    child: SingleChildScrollView(
                      child: _buildFormattedReport(aiAdvice),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildResultSection(
                  title: 'Heatmap',
                  icon: Icons.image_search_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 190,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildHeatmapWidget(
                            overlayDataUrl: overlayDataUrl,
                            overlayImageUrl: overlayImageUrl,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Red regions indicate high probability areas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
                    child: const Text(
                      'Close Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

  Widget _buildHeatmapWidget({
    required String? overlayDataUrl,
    required String? overlayImageUrl,
  }) {
    if (overlayDataUrl != null && overlayDataUrl.isNotEmpty) {
      return _buildBase64Image(overlayDataUrl);
    }

    if (overlayImageUrl != null && overlayImageUrl.isNotEmpty) {
      return Image.network(
        overlayImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return const Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.grey),
          SizedBox(width: 8),
          Text('No heatmap available'),
        ],
      ),
    );
  }

  String? _pickFirstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  dynamic _pickFirstValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String _formatConfidence(dynamic value) {
    if (value == null) {
      return 'N/A';
    }

    if (value is num) {
      return '${value.toStringAsFixed(2)}%';
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return 'N/A';
    }
    if (text.endsWith('%')) {
      return text;
    }

    final parsed = double.tryParse(text);
    if (parsed != null) {
      return '${parsed.toStringAsFixed(2)}%';
    }

    return text;
  }

  Widget _buildFormattedReport(String report) {
    final String source = report.trim();
    if (source.isEmpty) {
      return Text(
        'No additional notes were returned.',
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

  Widget _buildBase64Image(String dataUrl) {
    try {
      // Check if it has prefix
      String base64String = dataUrl;
      if (dataUrl.contains(',')) {
        base64String = dataUrl.split(',')[1];
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Text('Error decoding image');
          },
        ),
      );
    } catch (e) {
      return Text('Invalid image data: $e');
    }
  }

  String? _pickUrl(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty && !_looksLikeDataUri(value)) {
        return value;
      }
    }
    return null;
  }

  bool _looksLikeDataUri(String value) {
    return value.startsWith('data:image/') || value.length > 1000;
  }

  void _showSupportedPestsSheet() {
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
            heightFactor: 0.6,
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
                          Icons.bug_report_outlined,
                          color: Color(0xFF346E05),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Supported Pests',
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
                    'The current model is optimized for these classes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _supportedPestClasses
                            .map(
                              (pest) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAEF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFD7E2B7)),
                                ),
                                child: Text(
                                  pest,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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

  Future<void> _savePestHistory(
    String detectedPest,
    String confidence,
    String aiAdvice,
    String? imageUrl,
    String? overlayImageUrl,
    String? capturedImageBase64,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await HistoryService.savePestResult(user.uid, {
        'predicted_class': detectedPest,
        'confidence': confidence,
        'advice': aiAdvice,
        'image_url': imageUrl,
        'overlay_image_url': overlayImageUrl,
        'captured_image_base64': capturedImageBase64,
        'result_source': 'aws_pest_api',
      });
    } catch (e) {
      debugPrint('Failed to save pest history: $e');
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
