import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/error_handler.dart';
import '../services/image_optimizer.dart';
import '../services/input_validator.dart';
import '../widgets/loading_overlay.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';
import 'scan_screen.dart';
import 'schedule_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primary = Color(0xFF447804);
  static const Color _accent = Color(0xFF346E05);
  static const Color _softGreen = Color(0xFFEFF6E7);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAdmin = false;

  bool _weatherAlerts = true;
  bool _careReminders = true;
  bool _scanReports = true;
  bool _analyticsSharing = false;
  bool _diagnosticSharing = true;

  final ImagePicker _imagePicker = ImagePicker();

  String _name = 'GrowLens User';
  String _email = '';
  String _phone = '';
  String _location = '';
  String _about = '';
  String? _profilePhotoUrl;

  _ProfileStats _stats = const _ProfileStats(
    plants: 0,
    healthy: 0,
    needsCare: 0,
    pestScans: 0,
    diseaseScans: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<User?> _resolveAuthenticatedUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;

    try {
      return await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    final user = await _resolveAuthenticatedUser();
    debugPrint('ProfileScreen: FirebaseAuth currentUser uid = ${user?.uid}');
    debugPrint(
      'ProfileScreen: active Firebase projectId = ${FirebaseFirestore.instance.app.options.projectId}',
    );

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Please login to view your profile.', isError: true);
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      debugPrint('ProfileScreen: fetching profile doc at path = ${userRef.path}');

      // Ensure /users/{uid} exists so profile reads/writes always have a valid target.
      await userRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': (user.displayName ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final userDoc = await userRef.get();
      debugPrint(
        'ProfileScreen: profile doc exists=${userDoc.exists}, id=${userDoc.id}, expectedUid=${user.uid}',
      );

      final plants = await _safeGetSubcollectionData(userRef, 'plants');
      final pestHistory = await _safeGetSubcollectionData(userRef, 'pest_history');
      final diseaseHistory = await _safeGetSubcollectionData(userRef, 'disease_history');

      final data = userDoc.data() ?? <String, dynamic>{};
      final allHistory = [
        ...pestHistory,
        ...diseaseHistory,
      ];

      int healthyCount = 0;
      for (final item in allHistory) {
        final predicted = (item['predicted_class'] ??
                item['pest_name'] ??
                item['detected_pest'] ??
                item['label'] ??
                '')
            .toString()
            .toLowerCase();
        final report = (item['report'] ?? item['advice'] ?? item['ai_advice'] ?? '')
            .toString()
            .toLowerCase();
        if (predicted.contains('healthy') || report.contains('healthy')) {
          healthyCount++;
        }
      }

      final totalScans = pestHistory.length + diseaseHistory.length;
      final needsCareCount = max(totalScans - healthyCount, 0);

      if (!mounted) return;
      setState(() {
        _name = (data['name']?.toString().trim().isNotEmpty ?? false)
            ? data['name'].toString().trim()
            : (user.displayName?.trim().isNotEmpty ?? false)
                ? user.displayName!.trim()
                : 'GrowLens User';
        _email = (data['email']?.toString().trim().isNotEmpty ?? false)
            ? data['email'].toString().trim()
            : (user.email ?? '');
        _phone = data['phone']?.toString() ?? '';
        _location = data['location']?.toString() ?? '';
        _about = data['about']?.toString() ?? '';
        _profilePhotoUrl = data['photoUrl']?.toString();
        _isAdmin = (data['role']?.toString().toLowerCase() ?? 'user') == 'admin';

        _stats = _ProfileStats(
          plants: plants.length,
          healthy: healthyCount,
          needsCare: needsCareCount,
          pestScans: pestHistory.length,
          diseaseScans: diseaseHistory.length,
        );

        _weatherAlerts = prefs.getBool('notif_weather_alerts') ?? true;
        _careReminders = prefs.getBool('notif_care_reminders') ?? true;
        _scanReports = prefs.getBool('notif_scan_reports') ?? true;
        _analyticsSharing = prefs.getBool('privacy_analytics_sharing') ?? false;
        _diagnosticSharing = prefs.getBool('privacy_diagnostic_sharing') ?? true;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.code == 'permission-denied') {
        _showSnack(
          'Permission denied while loading profile from /users/${user.uid}. Check Firestore rules and active Firebase project.',
          isError: true,
        );
        return;
      }
      _showSnack('Could not load profile: ${e.message ?? e.code}', isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Could not load profile: $e', isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> _safeGetSubcollectionData(
    DocumentReference<Map<String, dynamic>> userRef,
    String collectionName,
  ) async {
    final query = userRef.collection(collectionName);
    debugPrint('ProfileScreen: fetching subcollection path = ${query.path}');
    try {
      final snap = await query.get();
      return snap.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      debugPrint(
        'ProfileScreen: subcollection read failed for ${query.path} (${e.code}: ${e.message})',
      );
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Profile'),
              centerTitle: true,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadProfile,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  _buildStatsRow(),
                  const SizedBox(height: 14),
                  _buildQuickActions(),
                  const SizedBox(height: 14),
                  _buildSettingsCard(),
                  const SizedBox(height: 14),
                  _buildAccountActions(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final avatar = _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
        ? CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage(_profilePhotoUrl!),
            backgroundColor: Colors.white.withValues(alpha: 0.24),
          )
        : CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.24),
            child: Text(
              _name.isNotEmpty ? _name[0].toUpperCase() : 'G',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isSaving ? null : _changeProfilePhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _isAdmin ? 'Admin Account' : 'Standard Account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            tooltip: 'Edit',
            onPressed: _isSaving ? null : _editProfile,
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    if (_isSaving) return;

    final choice = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'remove') {
      await _updateProfilePhoto(null);
      return;
    }

    final permission = choice == 'gallery' ? Permission.photos : Permission.camera;
    final status = await permission.request();

    if (!status.isGranted) {
      if (!mounted) return;
      _showSnack(
        'Permission denied. Go to Settings > Permissions to enable ${choice == 'gallery' ? 'Photo' : 'Camera'} access.',
        isError: true,
      );
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (picked == null) return;

    await _uploadProfilePhotoToStorage(picked);
  }

  Future<void> _uploadProfilePhotoToStorage(XFile photoFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check file size before upload
      final fileSize = await photoFile.length();
      if (!InputValidator.isFileSizeValid(fileSize)) {
        if (!mounted) return;
        ErrorHandler.showSnackbar(
          context,
          message: InputValidator.getFileSizeError(),
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      LoadingOverlay.show(context, message: 'Uploading photo...');

      // Compress image before upload
      final compressedBytes = await ImageOptimizer.compressImage(photoFile);
      if (compressedBytes == null) {
        LoadingOverlay.hide();
        if (!mounted) return;
        ErrorHandler.showSnackbar(
          context,
          message: 'Failed to process image. Please try another one.',
          isError: true,
        );
        return;
      }

      final fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('profile_photos/$fileName');

      await ref.putData(compressedBytes);
      final photoUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': photoUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      LoadingOverlay.hide();

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = photoUrl;
      });

      ErrorHandler.showSnackbar(
        context,
        message: 'Profile photo updated.',
        isError: false,
      );
    } catch (e) {
      LoadingOverlay.hide();
      if (!mounted) return;
      final userMessage = ErrorHandler.getUserMessage(e);
      ErrorHandler.showSnackbar(
        context,
        message: 'Failed to upload photo: $userMessage',
        isError: true,
      );
      debugPrint('Photo upload error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _updateProfilePhoto(String? photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isSaving = true);

      if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(_profilePhotoUrl!).delete();
        } catch (e) {
          debugPrint('Failed to delete old photo: $e');
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': photoUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = photoUrl;
      });
      _showSnack(photoUrl == null ? 'Profile photo removed.' : 'Profile photo updated.');
    } catch (e) {
      _showSnack('Failed to update profile photo: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip('Plants', _stats.plants.toString(), Icons.local_florist),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip('Healthy', _stats.healthy.toString(), Icons.check_circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip('Needs Care', _stats.needsCare.toString(), Icons.warning_amber),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _softGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E7C7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF243C07),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = <_QuickAction>[
      _QuickAction(
        title: 'Add Plant',
        icon: Icons.add,
        tint: const Color(0xFF00B050),
        bg: const Color(0xFFE9F6EC),
        onTap: _showAddPlantDialog,
      ),
      _QuickAction(
        title: 'My Plants',
        icon: Icons.local_florist,
        tint: const Color(0xFF2E7D32),
        bg: const Color(0xFFEAF5EA),
        onTap: _showMyPlantsBottomSheet,
      ),
      _QuickAction(
        title: 'Scan Plant',
        icon: Icons.camera_alt,
        tint: const Color(0xFF1E88E5),
        bg: const Color(0xFFEAF3FC),
        onTap: _openScan,
      ),
      _QuickAction(
        title: 'Smart Care',
        icon: Icons.water_drop,
        tint: const Color(0xFFEF6C00),
        bg: const Color(0xFFFFF0E4),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScheduleScreen()),
          );
        },
      ),
      _QuickAction(
        title: 'Help Center',
        icon: Icons.help,
        tint: const Color(0xFF9C27B0),
        bg: const Color(0xFFF6EBF8),
        onTap: _showHelpCenter,
      ),
      if (_isAdmin)
        _QuickAction(
          title: 'Admin Panel',
          icon: Icons.admin_panel_settings,
          tint: const Color(0xFF455A64),
          bg: const Color(0xFFECEFF1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
            );
          },
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFF6D6D6D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions
                    .map(
                      (action) => SizedBox(
                        width: cardWidth,
                        child: _buildQuickActionCard(action),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return Material(
      color: action.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: action.tint.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.tint, size: 34),
              const SizedBox(height: 12),
              Text(
                action.title,
                style: TextStyle(
                  color: action.tint,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: Column(
        children: [
          _settingsTile(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'Edit name, phone, location, and bio',
            onTap: _editProfile,
          ),
          _settingsTile(
            icon: Icons.local_florist_outlined,
            title: 'My Plants',
            subtitle: 'View and manage plants you added',
            onTap: _showMyPlantsBottomSheet,
          ),
          _settingsTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Control weather and care reminders',
            onTap: _openNotificationSettings,
          ),
          _settingsTile(
            icon: Icons.shield_outlined,
            title: 'Privacy & Security',
            subtitle: 'Manage privacy and account security',
            onTap: _openPrivacySettings,
          ),
          _settingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Send a secure password reset link',
            onTap: _changePassword,
          ),
          _settingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get assistance and report issues',
            onTap: _showHelpCenter,
          ),
          _settingsTile(
            icon: Icons.info_outline,
            title: 'About GrowLens',
            subtitle: 'Version, app info, and mission',
            onTap: _showAboutGrowLens,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
      ],
    );
  }

  Widget _buildAccountActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _primary),
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _confirmDeleteAccount,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete Account'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone);
    final locationController = TextEditingController(text: _location);
    final aboutController = TextEditingController(text: _about);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personal Information'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: aboutController,
                  decoration: const InputDecoration(labelText: 'About'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(dialogContext);

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();
              final newLocation = locationController.text.trim();
              final newAbout = aboutController.text.trim();

              try {
                setState(() => _isSaving = true);
                if (user.displayName != newName) {
                  await user.updateDisplayName(newName);
                }
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                  'name': newName,
                  'email': user.email,
                  'phone': newPhone,
                  'location': newLocation,
                  'about': newAbout,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!mounted) return;
                setState(() {
                  _name = newName;
                  _phone = newPhone;
                  _location = newLocation;
                  _about = newAbout;
                });
                _showSnack('Profile updated successfully.');
              } catch (e) {
                _showSnack('Failed to update profile: $e', isError: true);
              } finally {
                if (mounted) {
                  setState(() => _isSaving = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    locationController.dispose();
    aboutController.dispose();
  }

  Future<void> _openNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool weather = _weatherAlerts;
        bool care = _careReminders;
        bool reports = _scanReports;

        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  _switchRow(
                    title: 'Weather Alerts',
                    subtitle: 'Rain, wind, and temperature alerts',
                    value: weather,
                    onChanged: (value) {
                      setModalState(() => weather = value);
                    },
                  ),
                  _switchRow(
                    title: 'Care Reminders',
                    subtitle: 'Watering and maintenance reminders',
                    value: care,
                    onChanged: (value) {
                      setModalState(() => care = value);
                    },
                  ),
                  _switchRow(
                    title: 'Scan Reports',
                    subtitle: 'Disease/pest result updates',
                    value: reports,
                    onChanged: (value) {
                      setModalState(() => reports = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('notif_weather_alerts', weather);
                        await prefs.setBool('notif_care_reminders', care);
                        await prefs.setBool('notif_scan_reports', reports);
                        if (!mounted) return;
                        setState(() {
                          _weatherAlerts = weather;
                          _careReminders = care;
                          _scanReports = reports;
                        });
                        Navigator.pop(context);
                        _showSnack('Notification settings saved.');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _primary),
                      child: const Text('Save Settings'),
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

  Future<void> _openPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool analytics = _analyticsSharing;
        bool diagnostics = _diagnosticSharing;

        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Privacy & Security',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  _switchRow(
                    title: 'Analytics Sharing',
                    subtitle: 'Help improve app features with anonymous usage',
                    value: analytics,
                    onChanged: (value) => setModalState(() => analytics = value),
                  ),
                  _switchRow(
                    title: 'Diagnostic Sharing',
                    subtitle: 'Share diagnostics to improve AI suggestions',
                    value: diagnostics,
                    onChanged: (value) => setModalState(() => diagnostics = value),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_all, color: _primary),
                    title: const Text('Copy Data Summary'),
                    subtitle: const Text('Copy your profile and usage summary'),
                    onTap: () async {
                      final summary = _buildDataSummary();
                      await Clipboard.setData(ClipboardData(text: summary));
                      if (!mounted) return;
                      _showSnack('Profile summary copied.');
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setBool('privacy_analytics_sharing', analytics);
                        await prefs.setBool('privacy_diagnostic_sharing', diagnostics);
                        if (!mounted) return;
                        setState(() {
                          _analyticsSharing = analytics;
                          _diagnosticSharing = diagnostics;
                        });
                        Navigator.pop(context);
                        _showSnack('Privacy settings saved.');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _primary),
                      child: const Text('Save Privacy Settings'),
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

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        activeColor: _primary,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? _email;
    if (email.isEmpty) {
      _showSnack('No email found for this account.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Change Password'),
            content: Text(
              'Send a secure password reset link to $email?',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send Link'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await AuthService().sendPasswordResetEmail(email);
      _showSnack('Password reset link sent to $email');
    } catch (e) {
      _showSnack('Could not send reset link: $e', isError: true);
    }
  }

  Future<void> _showHelpCenter() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Help Center',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _helpTile(
                icon: Icons.chat_bubble_outline,
                title: 'Contact Support',
                subtitle: 'We will respond within 24 hours',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack('Support: support@growlens.app');
                },
              ),
              _helpTile(
                icon: Icons.bug_report_outlined,
                title: 'Report an Issue',
                subtitle: 'Share app bug details with our team',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack('Issue logging opened. Describe the problem in detail.');
                },
              ),
              _helpTile(
                icon: Icons.menu_book_outlined,
                title: 'FAQ',
                subtitle: 'Best practices for better detection results',
                onTap: () {
                  Navigator.pop(context);
                  _showFaqDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _softGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _showFaqDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GrowLens FAQ'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Capture 3 angles for better scan accuracy.\n'
            '2. Keep image lighting bright and stable.\n'
            '3. Review scan reports and follow treatment advice.\n'
            '4. Use Smart Care schedules to avoid overwatering.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutGrowLens() {
    showAboutDialog(
      context: context,
      applicationName: 'GrowLens',
      applicationVersion: '1.0.0',
      applicationIcon: const CircleAvatar(
        backgroundColor: _softGreen,
        child: Icon(Icons.eco, color: _primary),
      ),
      children: const [
        Text(
          'GrowLens is an AI-powered gardening assistant for disease detection, pest identification, and smart care guidance.',
        ),
      ],
    );
  }

  Future<void> _showAddPlantDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login again to add plants.', isError: true);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final speciesController = TextEditingController();
    final locationController = TextEditingController(text: _location);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Plant'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Plant Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Plant name is required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: speciesController,
                  decoration: const InputDecoration(
                    labelText: 'Species (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Placement (e.g., balcony, kitchen)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final plantName = nameController.text.trim();
              final species = speciesController.text.trim();
              final placement = locationController.text.trim();

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('plants')
                    .add({
                  'name': plantName,
                  'species': species,
                  'placement': placement,
                  'healthStatus': 'unknown',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.pop(dialogContext);
                _showSnack('Plant added successfully.');
                _loadProfile();
              } catch (e) {
                _showSnack('Could not add plant: $e', isError: true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    nameController.dispose();
    speciesController.dispose();
    locationController.dispose();
  }

  Future<void> _showMyPlantsBottomSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login again to view your plants.', isError: true);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'My Plants',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Plants added from profile',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('plants')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Could not load plants: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No plants added yet.\nUse "Add Plant" to create your list.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final name =
                              (data['name']?.toString().trim().isNotEmpty ?? false)
                                  ? data['name'].toString().trim()
                                  : 'Unnamed Plant';
                          final species = data['species']?.toString().trim() ?? '';
                          final placement = data['placement']?.toString().trim() ?? '';
                          final health = data['healthStatus']?.toString().trim() ?? 'unknown';

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6FAEE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDCE8C9)),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE3F2DA),
                                child: Icon(Icons.eco, color: _primary),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  if (species.isNotEmpty) 'Species: $species',
                                  if (placement.isNotEmpty) 'Placement: $placement',
                                  'Health: $health',
                                ].join('\n'),
                                style: const TextStyle(fontSize: 12, height: 1.35),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete plant',
                                onPressed: () async {
                                  try {
                                    await doc.reference.delete();
                                    if (!mounted) return;
                                    _loadProfile();
                                    _showSnack('Plant removed.');
                                  } catch (e) {
                                    _showSnack('Could not remove plant: $e', isError: true);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showSnack('Sign out failed: $e', isError: true);
    }
  }

  void _openScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen(initialIndex: 0)),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is permanent. Type DELETE to continue.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Type DELETE',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  final canDelete = controller.text.trim().toUpperCase() == 'DELETE';
                  Navigator.pop(dialogContext, canDelete);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    controller.dispose();
    if (!confirmed) return;

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isSaving = true);
      final uid = user.uid;
      final db = FirebaseFirestore.instance;
      await user.delete();

      // Best-effort profile cleanup after auth deletion.
      for (final subCollection in const [
        'plants',
        'pest_history',
        'disease_history',
        'garden_design_history',
      ]) {
        try {
          final snapshot = await db
              .collection('users')
              .doc(uid)
              .collection(subCollection)
              .get();
          if (snapshot.docs.isEmpty) continue;

          final batch = db.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } catch (_) {
          // Ignore cleanup failures; account auth is already deleted.
        }
      }
      try {
        await db.collection('users').doc(uid).delete();
      } catch (_) {
        // Ignore profile doc cleanup failures.
      }

      if (!mounted) return;
      _showSnack('Account deleted successfully.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack(
          'For security, please logout and login again, then retry account deletion.',
          isError: true,
        );
      } else {
        _showSnack('Could not delete account: ${e.message}', isError: true);
      }
    } catch (e) {
      _showSnack('Could not delete account: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _buildDataSummary() {
    return 'GrowLens Profile Summary\n'
        'Name: $_name\n'
        'Email: $_email\n'
        'Phone: ${_phone.isEmpty ? "-" : _phone}\n'
        'Location: ${_location.isEmpty ? "-" : _location}\n'
        'Plants: ${_stats.plants}\n'
        'Healthy Results: ${_stats.healthy}\n'
        'Needs Care Results: ${_stats.needsCare}\n'
        'Pest Scans: ${_stats.pestScans}\n'
        'Disease Scans: ${_stats.diseaseScans}\n'
        'Weather Alerts: ${_weatherAlerts ? "On" : "Off"}\n'
        'Care Reminders: ${_careReminders ? "On" : "Off"}\n'
        'Scan Reports: ${_scanReports ? "On" : "Off"}\n'
        'Analytics Sharing: ${_analyticsSharing ? "On" : "Off"}\n'
        'Diagnostic Sharing: ${_diagnosticSharing ? "On" : "Off"}\n';
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primary,
      ),
    );
  }
}

class _ProfileStats {
  final int plants;
  final int healthy;
  final int needsCare;
  final int pestScans;
  final int diseaseScans;

  const _ProfileStats({
    required this.plants,
    required this.healthy,
    required this.needsCare,
    required this.pestScans,
    required this.diseaseScans,
  });
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color tint;
  final Color bg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.title,
    required this.icon,
    required this.tint,
    required this.bg,
    required this.onTap,
  });
}
