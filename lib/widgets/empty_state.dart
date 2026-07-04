import 'package:flutter/material.dart';

/// Reusable empty state widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: iconColor ?? Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF447804),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Specific empty states for common scenarios
class NoTasksEmpty extends StatelessWidget {
  final VoidCallback? onAddTask;

  const NoTasksEmpty({super.key, this.onAddTask});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.task_alt,
      title: 'No Tasks Yet',
      message: 'Create your first care task to stay on top of your plants',
      onAction: onAddTask,
      actionLabel: 'Add Task',
      iconColor: Colors.amber,
    );
  }
}

class NoHistoryEmpty extends StatelessWidget {
  const NoHistoryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.history,
      title: 'No Detection History',
      message: 'Run plant health scans to see detection results here',
      iconColor: Colors.blue,
    );
  }
}

class NoPlantsEmpty extends StatelessWidget {
  const NoPlantsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.nature,
      title: 'No Plants Added',
      message: 'Start by adding your first plant to the garden',
      iconColor: Colors.green,
    );
  }
}
