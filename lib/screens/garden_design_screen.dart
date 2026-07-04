import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/garden_design_service.dart';
import '../services/history_service.dart';
import '../services/weather_service.dart';
import 'history_screen.dart';

class GardenDesignScreen extends StatefulWidget {
  const GardenDesignScreen({super.key});

  @override
  State<GardenDesignScreen> createState() => _GardenDesignScreenState();
}

class _GardenDesignScreenState extends State<GardenDesignScreen> {
  final ImagePicker _picker = ImagePicker();
  final GardenDesignService _gardenDesignService = GardenDesignService();
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _locationController = TextEditingController();

  static const String _defaultCity = 'Faisalabad';

  static const List<String> _styles = [
    'Mughal',
    'Modern',
    'Minimalist',
    'Islamic',
  ];

  XFile? _selectedImage;
  String _selectedStyle = 'Minimalist';
  bool _isLoading = false;
  String? _resultImageUrl;
  String? _aiAnalysis;
  String? _promptUsed;
  String? _errorMessage;
  bool _isResolvingLocation = false;
  String? _resolvedWeatherLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillLocationFromWeather();
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _prefillLocationFromWeather() async {
    if (_locationController.text.trim().isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isResolvingLocation = true;
      });
    }

    try {
      final weather = await _weatherService.getCurrentWeather(_defaultCity);

      final locationName = (weather['locationName'] as String?)?.trim() ?? '';
      if (locationName.isNotEmpty && mounted) {
        setState(() {
          _resolvedWeatherLocation = locationName;
          _locationController.text = locationName;
        });
      }
    } catch (e) {
      debugPrint('GardenDesignScreen: Failed to prefill location from weather: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingLocation = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      if (!kIsWeb) {
        final permission = await Permission.photos.request();
        if (!permission.isGranted && !permission.isLimited) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo library access is required.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (picked != null && mounted) {
        setState(() {
          _selectedImage = picked;
          _resultImageUrl = null;
          _aiAnalysis = null;
          _promptUsed = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image from gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );

    if (picked != null && mounted) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera access is required.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedImage = picked;
        _resultImageUrl = null;
        _aiAnalysis = null;
        _promptUsed = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _designGarden() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a garden photo first.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_locationController.text.trim().isEmpty) {
        await _prefillLocationFromWeather();
      }

      final resolvedCity = _resolvedWeatherLocation?.trim().isNotEmpty == true
          ? _resolvedWeatherLocation!.trim()
          : (_locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : _defaultCity);

      final result = await _gardenDesignService.generateGardenDesign(
        imageFile: _selectedImage!,
        city: resolvedCity,
        style: _selectedStyle,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final city = resolvedCity.trim();
          await HistoryService.saveGardenDesignResult(user.uid, {
            'city': city.isEmpty ? _defaultCity : city,
            'style': _selectedStyle,
            'ai_analysis': result['ai_analysis'],
            'prompt_used': result['prompt_used'],
            'designed_image_base64': result['designed_image_base64'],
            'result_source': 'garden_design_api',
          });
        } catch (saveError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Design generated, but failed to save history: $saveError'),
                backgroundColor: Colors.orange.shade700,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _resultImageUrl = result['designed_image_base64'] as String?;
        _aiAnalysis = result['ai_analysis'] as String?;
        _promptUsed = result['prompt_used'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garden Design'),
        backgroundColor: const Color(0xFF2E6B2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Garden History',
            icon: const Icon(Icons.history),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please login to view your garden history.'),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryScreen(initialTabIndex: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _resultImageUrl != null
                ? _buildResultImage()
                : _buildImagePicker(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6B2E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A8C4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              enabled: !_isLoading && !_isResolvingLocation,
              decoration: InputDecoration(
                labelText: 'Garden Location',
                hintText: _isResolvingLocation
                    ? 'Fetching Faisalabad from WeatherAPI...'
                    : 'Auto-filled from WeatherAPI location',
                prefixIcon: const Icon(
                  Icons.location_on,
                  color: Color(0xFF2E6B2E),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E6B2E)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: _styles
                  .map((style) => DropdownMenuItem(
                        value: style,
                        child: Text(style),
                      ))
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedStyle = value);
                    },
              decoration: InputDecoration(
                labelText: 'Choose Style',
                prefixIcon: const Icon(Icons.yard, color: Color(0xFF2E6B2E)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _designGarden,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text('AI is designing your garden...'),
                        ),
                      ],
                    )
                  : const Text(
                      'Design My Garden',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            if (_aiAnalysis != null) ...[
              const SizedBox(height: 24),
              _buildInsightCard(
                title: 'AI Plant Recommendations',
                subtitle:
                    'Well-structured suggestions for plants, layout, and care in your selected style.',
                icon: Icons.eco_outlined,
                accentColor: const Color(0xFF2E6B2E),
                child: _buildProfessionalRecommendation(),
              ),
            ],
            if (_promptUsed != null && _promptUsed!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInsightCard(
                title: 'View AI Prompt',
                subtitle: 'Debug view of the exact prompt sent to the model.',
                icon: Icons.psychology_outlined,
                accentColor: const Color(0xFF3A5A40),
                child: _buildStructuredText(
                  _promptUsed!,
                  bodyStyle: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: Color(0xFF27302B),
                  ),
                ),
                isCollapsible: true,
                collapsedLabel: 'Show Prompt Details',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget child,
    bool isCollapsible = false,
    String collapsedLabel = 'View Details',
  }) {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Color(0xFF506156),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FCF7),
            Color(0xFFECF7EC),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (!isCollapsible) child,
            if (isCollapsible)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    collapsedLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  iconColor: accentColor,
                  collapsedIconColor: accentColor.withValues(alpha: 0.7),
                  children: [child],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredText(
    String rawText, {
    required TextStyle bodyStyle,
  }) {
    final lines = rawText.replaceAll('\r\n', '\n').trim().split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final markdownHeading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (markdownHeading != null) {
        widgets.add(_buildHeadingChip(markdownHeading.group(2)!));
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final inlineHeading =
          RegExp(r'^([A-Za-z][A-Za-z\s/&-]{2,40}):\s*(.*)$').firstMatch(line);
      if (inlineHeading != null) {
        widgets.add(_buildHeadingChip(inlineHeading.group(1)!));
        final body = inlineHeading.group(2) ?? '';
        if (body.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(body, style: bodyStyle),
            ),
          );
        } else {
          widgets.add(const SizedBox(height: 8));
        }
        continue;
      }

      final bullet = RegExp(r'^(?:[-*]|\d+[.)])\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E6B2E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(bullet.group(1)!, style: bodyStyle)),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(line, style: bodyStyle),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildProfessionalRecommendation() {
    final city = _resolvedWeatherLocation?.trim().isNotEmpty == true
      ? _resolvedWeatherLocation!.trim()
      : (_locationController.text.trim().isEmpty
        ? _defaultCity
        : _locationController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetaPill(Icons.location_on_outlined, city),
            _buildMetaPill(Icons.style_outlined, _selectedStyle),
          ],
        ),
        const SizedBox(height: 12),
        _buildStructuredText(
          _aiAnalysis ?? '',
          bodyStyle: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF1E3220),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFD8BF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF2E6B2E)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF245424),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadingChip(String heading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2E6B2E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        heading,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF245424),
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickFromGallery,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2E6B2E).withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildSelectedImagePreview(),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 60,
                    color: Color(0xFF2E6B2E),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Upload Your Garden Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text('Get AI-powered garden layout suggestions'),
                ],
              ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }

    if (kIsWeb) {
      return Image.network(
        _selectedImage!.path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Image.file(
      File(_selectedImage!.path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildResultImage() {
    if (_resultImageUrl == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Center(
          child: Text(
            'No generated image available.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    try {
      final Uint8List bytes = base64Decode(_resultImageUrl!);
      return GestureDetector(
        onTap: () => _showFullScreenImage(bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            height: 300,
            width: double.infinity,
          ),
        ),
      );
    } catch (_) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Center(
          child: Text(
            'Unable to load generated image.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  void _showFullScreenImage(Uint8List bytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.96),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
