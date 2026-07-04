import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/disease_api_service.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> {
  final List<XFile?> _selectedImages = [null, null, null];
  final List<Uint8List?> _imageBytes = [null, null, null];
  bool _isAnalyzing = false;
  final ImagePicker _imagePicker = ImagePicker();
  final DiseaseApiService _apiService = DiseaseApiService();
  int _currentAngle = 0; // 0: Whole plant, 1: Affected leaf, 2: Close-up

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Detection'),
        centerTitle: true,
        backgroundColor: const Color(0xFF447804),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Instructions Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF447804), Color(0xFF346E05)],
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
                    'Capture 3 Angles for Accurate Diagnosis',
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

            // Angle Selection Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAngleTab(0, 'Whole Plant', Icons.park),
                  _buildAngleTab(1, 'Affected Leaf', Icons.eco),
                  _buildAngleTab(2, 'Close-up', Icons.zoom_in),
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
                    onPressed: () => _pickImageForCurrentAngle(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF447804),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _pickImageForCurrentAngle(ImageSource.camera),
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
                      _buildProgressStep(0, 'Plant'),
                      Container(
                        height: 2,
                        width: 40,
                        color: _selectedImages[0] != null
                            ? const Color(0xFF447804)
                            : Colors.grey[300],
                      ),
                      _buildProgressStep(1, 'Leaf'),
                      Container(
                        height: 2,
                        width: 40,
                        color: _selectedImages[1] != null
                            ? const Color(0xFF447804)
                            : Colors.grey[300],
                      ),
                      _buildProgressStep(2, 'Close-up'),
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
                onPressed: _canAnalyze() ? (_isAnalyzing ? null : _analyzeDisease) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canAnalyze()
                      ? const Color(0xFF447804)
                      : Colors.grey[400],
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF447804)),
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
          color: isSelected ? const Color(0xFF447804) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF447804) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF447804),
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
            color: hasImage ? const Color(0xFF447804) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasImage ? const Color(0xFF447804) : Colors.grey[300]!,
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
        return 'Whole Plant View';
      case 1:
        return 'Affected Leaf View';
      case 2:
        return 'Close-up View';
      default:
        return '';
    }
  }

  String _getAngleDescription(int angle) {
    switch (angle) {
      case 0:
        return 'Overall plant view for context';
      case 1:
        return 'Focus on diseased leaves';
      case 2:
        return 'Close-up of disease symptoms';
      default:
        return '';
    }
  }

  IconData _getAngleIcon(int angle) {
    switch (angle) {
      case 0:
        return Icons.park;
      case 1:
        return Icons.eco;
      case 2:
        return Icons.zoom_in;
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

  Future<void> _analyzeDisease() async {
    if (!_canAnalyze()) return;

    setState(() {
      _isAnalyzing = true;
    });

    List<Map<String, dynamic>> results = [];

    try {
      // Send 3 separate requests for each angle
      for (int i = 0; i < 3; i++) {
        try {
          final result = await _apiService.predictDisease(
            _imageBytes[i]!,
            _selectedImages[i]!.name,
          );
          results.add(result);
        } catch (e) {
          debugPrint('Request $i failed: $e');
        }
      }

      if (results.isEmpty) {
        throw Exception('All requests failed');
      }

      // Find result with highest confidence
      Map<String, dynamic> bestResult = results[0];
      double maxConfidence = _parseConfidence(results[0]['confidence_percent']);

      for (var result in results) {
        double currentConf = _parseConfidence(result['confidence_percent']);
        if (currentConf > maxConfidence) {
          maxConfidence = currentConf;
          bestResult = result;
        }
      }

      if (mounted) {
        _showRealResultDialog(
          json: bestResult,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing disease: $e');
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

  double _parseConfidence(dynamic confVal) {
    if (confVal is num) {
      return confVal.toDouble();
    } else if (confVal is String) {
      String cleanConf = confVal.replaceAll('%', '').trim();
      return double.tryParse(cleanConf) ?? 0.0;
    }
    return 0.0;
  }

  void _showRealResultDialog({required Map<String, dynamic> json}) {
    String predictedClass = DiseaseApiService.getDisplayName(json['class_name']?.toString() ?? 'Unknown');
    String confidence = json['confidence_percent']?.toString() ?? 'N/A';
    String? overlayDataUrl = json['overlay_image'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEFB8F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  size: 40,
                  color: Color(0xFF447804),
                ),
              ),
              const SizedBox(height: 16),
              
              // Disease Name
              Text(
                predictedClass.toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF243C07),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Confidence Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF447804),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Confidence: $confidence',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Heatmap Section
              if (overlayDataUrl != null && overlayDataUrl.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AI Analysis Heatmap',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF346E05),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildBase64Image(overlayDataUrl),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Red areas indicate disease symptoms and affected regions.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('No heatmap available'),
                    ],
                  ),
                ),
                
              const SizedBox(height: 24),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF447804),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
    );
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
}
