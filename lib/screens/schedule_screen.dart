import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/input_validator.dart';
import '../services/error_handler.dart';
import '../widgets/empty_state.dart';

class ScheduleScreen extends StatefulWidget {
  final bool showAppBar;

  const ScheduleScreen({super.key, this.showAppBar = true});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Timer? _reminderTimer;
  final Set<String> _remindedTaskKeys = <String>{};

  late List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Water Tomato Plants',
      'time': '07:00 AM',
      'plant': 'Tomato',
      'type': 'watering',
      'completed': false,
    },
    {
      'title': 'Fertilize Rose Bush',
      'time': '09:00 AM',
      'plant': 'Rose',
      'type': 'fertilizing',
      'completed': true,
    },
    {
      'title': 'Check for Pests',
      'time': '11:00 AM',
      'plant': 'All Plants',
      'type': 'inspection',
      'completed': false,
    },
    {
      'title': 'Prune Herb Garden',
      'time': '04:00 PM',
      'plant': 'Herbs',
      'type': 'pruning',
      'completed': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTasksFromStorage().then((_) {
      if (mounted) {
        _showTopTaskReminder();
        _startReminderTicker();
      }
    });
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasksFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('schedule_tasks');
      if (tasksJson != null) {
        final decoded = jsonDecode(tasksJson) as List<dynamic>;
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(
            decoded.map((task) => Map<String, dynamic>.from(task as Map<String, dynamic>)),
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to load tasks from storage: $e');
    }
  }

  Future<void> _saveTasksToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = jsonEncode(_tasks);
      await prefs.setString('schedule_tasks', tasksJson);
    } catch (e) {
      debugPrint('Failed to save tasks to storage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Care Schedule'),
              centerTitle: true,
            )
          : null,
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(DateTime.now()),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Weather Alert Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6D00), Color(0xFFFF9100)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weather Alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Rain expected tomorrow - Adjust watering schedule',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tasks Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Tasks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_tasks.where((task) => task['completed'] == true).length}/${_tasks.length} completed',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tasks List
          Expanded(
            child: _tasks.isEmpty
                ? NoTasksEmpty(onAddTask: _addNewTask)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return _buildTaskCard(task, index);
                    },
                  ),
          ),

          // Add Task Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: _addNewTask,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Task Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTaskColor(task['type']).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTaskIcon(task['type']),
                color: _getTaskColor(task['type']),
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // Task Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          task['completed'] ? TextDecoration.lineThrough : null,
                      color: task['completed'] ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task['time'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          decoration: task['completed']
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.park,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task['plant'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          decoration: task['completed']
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Complete Button
            Column(
              children: [
                IconButton(
                  tooltip: 'Edit task',
                  onPressed: () => _editTask(index),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete task',
                  onPressed: () => _deleteTask(index),
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                Checkbox(
                  value: task['completed'],
                  onChanged: (value) {
                    setState(() {
                      _tasks[index]['completed'] = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF00C853),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTaskIcon(String type) {
    switch (type) {
      case 'watering':
        return Icons.water_drop;
      case 'fertilizing':
        return Icons.eco;
      case 'pruning':
        return Icons.content_cut;
      case 'inspection':
        return Icons.search;
      default:
        return Icons.task;
    }
  }

  Color _getTaskColor(String type) {
    switch (type) {
      case 'watering':
        return const Color(0xFF2196F3);
      case 'fertilizing':
        return const Color(0xFF4CAF50);
      case 'pruning':
        return const Color(0xFFFF9800);
      case 'inspection':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTaskTypeLabel(String type) {
    switch (type) {
      case 'watering':
        return 'Watering';
      case 'fertilizing':
        return 'Fertilizing';
      case 'pruning':
        return 'Pruning';
      case 'inspection':
        return 'Inspection';
      default:
        return type;
    }
  }

  void _addNewTask() {
    final taskController = TextEditingController();
    final plantController = TextEditingController();
    String selectedType = 'watering';
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: taskController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    hintText: 'e.g., Water Tomato Plants',
                    errorText: null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: plantController,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Plant',
                    hintText: 'e.g., Tomato',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['watering', 'fertilizing', 'pruning', 'inspection']
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(_formatTaskTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Task Type'),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTimeOfDay(selectedTime),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedTime,
                        );
                        if (picked == null) return;
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      },
                      child: const Text('Set Time'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = taskController.text.trim();
                final plant = plantController.text.trim();

                // Validate inputs
                final titleError = InputValidator.validateTaskTitle(title);
                final plantError = InputValidator.validatePlantName(plant);

                if (titleError != null || plantError != null) {
                  ErrorHandler.showSnackbar(
                    this.context,
                    message: titleError ?? plantError ?? 'Invalid input',
                    isError: true,
                  );
                  return;
                }

                setState(() {
                  _tasks.add({
                    'title': title,
                    'time': _formatTimeOfDay(selectedTime),
                    'plant': plant,
                    'type': selectedType,
                    'completed': false,
                  });
                });
                _saveTasksToStorage();

                Navigator.pop(dialogContext);
                ErrorHandler.showSnackbar(
                  this.context,
                  message: 'Task added successfully!',
                  isError: false,
                );
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      taskController.dispose();
      plantController.dispose();
    });
  }

  void _editTask(int index) {
    final task = Map<String, dynamic>.from(_tasks[index]);
    final taskController =
        TextEditingController(text: task['title']?.toString() ?? '');
    final plantController =
        TextEditingController(text: task['plant']?.toString() ?? '');
    String selectedType = task['type']?.toString() ?? 'watering';
    bool completed = task['completed'] == true;
    TimeOfDay selectedTime =
        _parseTimeOfDay(task['time']?.toString() ?? '08:00 AM');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: taskController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Task Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: plantController,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Plant'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['watering', 'fertilizing', 'pruning', 'inspection']
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(_formatTaskTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Task Type'),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_formatTimeOfDay(selectedTime))),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedTime,
                        );
                        if (picked == null) return;
                        setDialogState(() => selectedTime = picked);
                      },
                      child: const Text('Set Time'),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Completed'),
                  value: completed,
                  onChanged: (value) => setDialogState(() => completed = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = taskController.text.trim();
                final plant = plantController.text.trim();

                // Validate inputs
                final titleError = InputValidator.validateTaskTitle(title);
                final plantError = InputValidator.validatePlantName(plant);

                if (titleError != null || plantError != null) {
                  ErrorHandler.showSnackbar(
                    this.context,
                    message: titleError ?? plantError ?? 'Invalid input',
                    isError: true,
                  );
                  return;
                }

                setState(() {
                  _tasks[index] = {
                    'title': title,
                    'time': _formatTimeOfDay(selectedTime),
                    'plant': plant,
                    'type': selectedType,
                    'completed': completed,
                  };
                });
                _saveTasksToStorage();

                Navigator.pop(dialogContext);
                ErrorHandler.showSnackbar(
                  this.context,
                  message: 'Task updated successfully!',
                  isError: false,
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      taskController.dispose();
      plantController.dispose();
    });
  }

  void _deleteTask(int index) {
    final removedTask = _tasks[index];
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasksToStorage();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${removedTask['title']}'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) {
      return TimeOfDay.now();
    }
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _showTopTaskReminder() {
    final pendingTasks =
        _tasks.where((task) => task['completed'] != true).toList(growable: false);
    if (pendingTasks.isEmpty) return;

    final task = pendingTasks.first;
    final title = task['title']?.toString() ?? 'Garden task';
    final time = task['time']?.toString() ?? 'Today';

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    SystemSound.play(SystemSoundType.alert);
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF2E7D32),
        content: Text(
          'Reminder: $title at $time',
          style: const TextStyle(color: Colors.white),
        ),
        leading: const Icon(Icons.notifications_active, color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      messenger.hideCurrentMaterialBanner();
    });
  }

  void _startReminderTicker() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDueTaskReminder();
    });
    _checkDueTaskReminder();
  }

  void _checkDueTaskReminder() {
    if (!mounted) return;

    final now = TimeOfDay.now();
    final dueTasks = _tasks.where((task) {
      if (task['completed'] == true) return false;
      final taskTime = _parseTimeOfDay(task['time']?.toString() ?? '');
      final isDue = taskTime.hour == now.hour && taskTime.minute == now.minute;
      if (!isDue) return false;

      final key = '${task['title']}_${task['time']}';
      return !_remindedTaskKeys.contains(key);
    }).toList(growable: false);

    if (dueTasks.isEmpty) return;

    final task = dueTasks.first;
    final key = '${task['title']}_${task['time']}';
    _remindedTaskKeys.add(key);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    SystemSound.play(SystemSoundType.alert);
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF2E7D32),
        content: Text(
          'Task due now: ${task['title']} (${task['time']})',
          style: const TextStyle(color: Colors.white),
        ),
        leading: const Icon(Icons.alarm_on, color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      messenger.hideCurrentMaterialBanner();
    });
  }
}
