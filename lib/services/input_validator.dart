/// Input validation utilities
class InputValidator {
  /// Validate task title - not empty, length limits
  static String? validateTaskTitle(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Task title cannot be empty';
    }
    if (value!.length < 3) {
      return 'Task title must be at least 3 characters';
    }
    if (value.length > 100) {
      return 'Task title must be less than 100 characters';
    }
    return null;
  }

  /// Validate time format HH:MM
  static String? validateTime(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Time cannot be empty';
    }
    try {
      final parts = value!.split(':');
      if (parts.length != 2) throw Exception('Invalid format');
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      if (hour < 0 || hour > 23) throw Exception('Invalid hour');
      if (minute < 0 || minute > 59) throw Exception('Invalid minute');
      
      return null;
    } catch (_) {
      return 'Time must be in HH:MM format (e.g., 08:30)';
    }
  }

  /// Validate plant name
  static String? validatePlantName(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Plant name cannot be empty';
    }
    if (value!.length < 2) {
      return 'Plant name must be at least 2 characters';
    }
    if (value.length > 50) {
      return 'Plant name must be less than 50 characters';
    }
    return null;
  }

  /// Check if file size is acceptable (max 10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  static bool isFileSizeValid(int fileSizeBytes) {
    return fileSizeBytes <= maxFileSizeBytes;
  }

  static String getFileSizeError() {
    return 'File size must be less than 10MB';
  }
}
