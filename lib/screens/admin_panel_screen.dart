import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();

  late final TabController _tabController;
  bool _isAdmin = false;
  bool _roleLoading = true;

  final TextEditingController _retrainReasonController = TextEditingController();
  String _selectedModelType = 'disease';

  final TextEditingController _datasetPlantController = TextEditingController();
  final TextEditingController _datasetDiseaseController = TextEditingController();
  final TextEditingController _datasetImageUrlController = TextEditingController();
  final TextEditingController _datasetTreatmentController = TextEditingController();
  final TextEditingController _datasetPreventionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _retrainReasonController.dispose();
    _datasetPlantController.dispose();
    _datasetDiseaseController.dispose();
    _datasetImageUrlController.dispose();
    _datasetTreatmentController.dispose();
    _datasetPreventionController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _roleLoading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = doc.data()?['role']?.toString() ?? 'user';
      if (mounted) {
        setState(() {
          _isAdmin = role == 'admin';
          _roleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _roleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final canAccessAdmin = user != null && !_roleLoading && _isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFF447804),
        foregroundColor: Colors.white,
        bottom: canAccessAdmin
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Users'),
                  Tab(text: 'Model'),
                  Tab(text: 'Dataset'),
                  Tab(text: 'Rules'),
                ],
              )
            : null,
      ),
      body: user == null
          ? const Center(child: Text('Please login to access admin panel.'))
          : _roleLoading
              ? const Center(child: CircularProgressIndicator())
              : !_isAdmin
                  ? _buildAccessDenied()
                  : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: _isAdmin ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Text(
                        'Current role: ${_isAdmin ? "admin" : "user"}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isAdmin ? Colors.green.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUsersTab(),
                          _buildModelTab(user),
                          _buildDatasetTab(user),
                          _buildRulesTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 54, color: Colors.red.shade400),
            const SizedBox(height: 12),
            const Text(
              'Access denied',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have admin permissions for this account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.streamUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            final userId = u['uid']?.toString() ?? u['id']?.toString() ?? '';
            final name = u['name']?.toString() ?? 'Unknown';
            final email = u['email']?.toString() ?? 'No email';
            final role = (u['role']?.toString() ?? 'user').toLowerCase();
            final isActive = (u['isActive'] as bool?) ?? true;
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text(email),
                trailing: SizedBox(
                  width: 190,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      DropdownButton<String>(
                        value: role == 'admin' ? 'admin' : 'user',
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('user')),
                          DropdownMenuItem(value: 'admin', child: Text('admin')),
                        ],
                        onChanged: !_isAdmin || userId.isEmpty
                            ? null
                            : (value) async {
                                if (value == null) return;
                                await _adminService.updateUserRole(userId, value);
                              },
                      ),
                      Switch(
                        value: isActive,
                        onChanged: !_isAdmin || userId.isEmpty
                            ? null
                            : (value) async {
                                await _adminService.setUserActive(userId, value);
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModelTab(User user) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _adminService.getModelPerformanceSummary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load metrics: ${snapshot.error}'),
                  ),
                );
              }

              final m = snapshot.data ?? {};
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Model Performance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Disease predictions: ${m['diseasePredictions'] ?? 0}'),
                      Text('Pest predictions: ${m['pestPredictions'] ?? 0}'),
                      Text(
                        'Avg disease confidence: ${_formatPercent(m['avgDiseaseConfidence'])}',
                      ),
                      Text(
                        'Avg pest confidence: ${_formatPercent(m['avgPestConfidence'])}',
                      ),
                      Text('Pending retrain requests: ${m['retrainRequested'] ?? 0}'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Retrain AI Model',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedModelType,
                    items: const [
                      DropdownMenuItem(value: 'disease', child: Text('Disease model')),
                      DropdownMenuItem(value: 'pest', child: Text('Pest model')),
                      DropdownMenuItem(value: 'both', child: Text('Both')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedModelType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _retrainReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: !_isAdmin
                        ? null
                        : () async {
                            final reason = _retrainReasonController.text.trim();
                            if (reason.isEmpty) {
                              _showSnack('Please enter a retrain reason.');
                              return;
                            }
                            await _adminService.requestRetrain(
                              requestedByUid: user.uid,
                              requestedByEmail: user.email ?? '',
                              modelType: _selectedModelType,
                              reason: reason,
                            );
                            _retrainReasonController.clear();
                            _showSnack('Retrain request submitted.');
                          },
                    child: const Text('Submit retrain request'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recent Retrain Requests',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.streamRetrainJobs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No retrain requests yet.'),
                );
              }
              return Column(
                children: jobs.map((job) {
                  final id = job['id']?.toString() ?? '';
                  final status = job['status']?.toString() ?? 'requested';
                  return Card(
                    child: ListTile(
                      title: Text('${job['modelType'] ?? 'model'} retrain'),
                      subtitle: Text('${job['reason'] ?? ''}\nStatus: $status'),
                      isThreeLine: true,
                      trailing: DropdownButton<String>(
                        value: _jobStatusValue(status),
                        items: const [
                          DropdownMenuItem(value: 'requested', child: Text('requested')),
                          DropdownMenuItem(value: 'running', child: Text('running')),
                          DropdownMenuItem(value: 'completed', child: Text('completed')),
                          DropdownMenuItem(value: 'failed', child: Text('failed')),
                        ],
                        onChanged: !_isAdmin || id.isEmpty
                            ? null
                            : (value) async {
                                if (value == null) return;
                                await _adminService.updateRetrainJobStatus(id, value);
                              },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetTab(User user) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Plant and Disease Dataset',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _datasetPlantController,
                  decoration: const InputDecoration(
                    labelText: 'Plant',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _datasetDiseaseController,
                  decoration: const InputDecoration(
                    labelText: 'Disease',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _datasetImageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _datasetTreatmentController,
                  decoration: const InputDecoration(
                    labelText: 'Treatment',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _datasetPreventionController,
                  decoration: const InputDecoration(
                    labelText: 'Prevention',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: !_isAdmin
                      ? null
                      : () async {
                          final plant = _datasetPlantController.text.trim();
                          final disease = _datasetDiseaseController.text.trim();
                          final imageUrl = _datasetImageUrlController.text.trim();
                          final treatment = _datasetTreatmentController.text.trim();
                          final prevention = _datasetPreventionController.text.trim();

                          if ([plant, disease, imageUrl, treatment, prevention]
                              .any((v) => v.isEmpty)) {
                            _showSnack('All dataset fields are required.');
                            return;
                          }

                          await _adminService.addDatasetEntry(
                            plant: plant,
                            disease: disease,
                            imageUrl: imageUrl,
                            treatment: treatment,
                            prevention: prevention,
                            createdByUid: user.uid,
                          );
                          _datasetPlantController.clear();
                          _datasetDiseaseController.clear();
                          _datasetImageUrlController.clear();
                          _datasetTreatmentController.clear();
                          _datasetPreventionController.clear();
                          _showSnack('Dataset entry added.');
                        },
                  child: const Text('Add dataset entry'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Validate Data Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _adminService.streamDatasetEntries(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Text('No dataset entries yet.');
            }
            return Column(
              children: entries.map((entry) {
                final id = entry['id']?.toString() ?? '';
                final validated = (entry['isValidated'] as bool?) ?? false;
                return Card(
                  child: ListTile(
                    title: Text('${entry['plant'] ?? ''} - ${entry['disease'] ?? ''}'),
                    subtitle: Text(
                      'Validated: ${validated ? "Yes" : "No"}\n${entry['imageUrl'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: !_isAdmin
                        ? null
                        : Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                tooltip: 'Approve',
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        await _adminService.validateDatasetEntry(
                                          entryId: id,
                                          isValidated: true,
                                          validationNote: 'Approved',
                                        );
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.orange),
                                tooltip: 'Reject',
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        await _adminService.validateDatasetEntry(
                                          entryId: id,
                                          isValidated: false,
                                          validationNote: 'Needs correction',
                                        );
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        await _adminService.deleteDatasetEntry(id);
                                      },
                              ),
                            ],
                          ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: !_isAdmin ? null : () => _openRuleDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add rule'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Update Treatment and Prevention Rules',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _adminService.streamTreatmentRules(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final rules = snapshot.data ?? [];
            if (rules.isEmpty) {
              return const Text('No treatment/prevention rules found.');
            }
            return Column(
              children: rules.map((rule) {
                final id = rule['id']?.toString();
                return Card(
                  child: ListTile(
                    title: Text('${rule['plant'] ?? ''} - ${rule['disease'] ?? ''}'),
                    subtitle: Text(
                      'Treatment: ${rule['treatment'] ?? ''}\nPrevention: ${rule['prevention'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: !_isAdmin
                        ? null
                        : Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openRuleDialog(existing: rule),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: id == null
                                    ? null
                                    : () async {
                                        await _adminService.deleteTreatmentRule(id);
                                      },
                              ),
                            ],
                          ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openRuleDialog({Map<String, dynamic>? existing}) async {
    final plantController =
        TextEditingController(text: existing?['plant']?.toString() ?? '');
    final diseaseController =
        TextEditingController(text: existing?['disease']?.toString() ?? '');
    final treatmentController =
        TextEditingController(text: existing?['treatment']?.toString() ?? '');
    final preventionController =
        TextEditingController(text: existing?['prevention']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Rule' : 'Edit Rule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plantController,
                decoration: const InputDecoration(labelText: 'Plant'),
              ),
              TextField(
                controller: diseaseController,
                decoration: const InputDecoration(labelText: 'Disease'),
              ),
              TextField(
                controller: treatmentController,
                decoration: const InputDecoration(labelText: 'Treatment'),
                maxLines: 2,
              ),
              TextField(
                controller: preventionController,
                decoration: const InputDecoration(labelText: 'Prevention'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final plant = plantController.text.trim();
              final disease = diseaseController.text.trim();
              final treatment = treatmentController.text.trim();
              final prevention = preventionController.text.trim();
              if ([plant, disease, treatment, prevention].any((v) => v.isEmpty)) {
                _showSnack('All rule fields are required.');
                return;
              }
              await _adminService.upsertTreatmentRule(
                ruleId: existing?['id']?.toString(),
                plant: plant,
                disease: disease,
                treatment: treatment,
                prevention: prevention,
              );
              if (!mounted) return;
              Navigator.of(this.context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatPercent(dynamic value) {
    if (value is num) return '${value.toStringAsFixed(1)}%';
    return '0.0%';
  }

  String _jobStatusValue(String value) {
    switch (value) {
      case 'running':
      case 'completed':
      case 'failed':
        return value;
      default:
        return 'requested';
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
