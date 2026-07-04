import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherForecast {
  final String date;
  final String dayName;
  final String condition;
  final String iconUrl;
  final double maxTempC;
  final double minTempC;
  final int rainChance;

  WeatherForecast({
    required this.date,
    required this.dayName,
    required this.condition,
    required this.iconUrl,
    required this.maxTempC,
    required this.minTempC,
    required this.rainChance,
  });

  /// Convert date string (YYYY-MM-DD) to day name
  static String getDayName(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } catch (e) {
      return dateStr;
    }
  }
}

class WeatherService {
  static const String apiKey = 'b9b15efefdf549c085c181243250812';
  static const String baseUrl = 'https://api.weatherapi.com/v1';

  /// Fetch current weather using WeatherAPI
  Future<Map<String, dynamic>> getCurrentWeather(String cityName) async {
    try {
      final String url = '$baseUrl/current.json?key=$apiKey&q=${Uri.encodeComponent(cityName)}&aqi=no';
      debugPrint('📡 WeatherAPI current call: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Weather API request timeout'),
      );

      _logResponse('Direct API call (Current)', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final current = json['current'];
        final location = json['location'];

        final String locationName = location != null
            ? '${location['name'] ?? ''}${(location['region'] != null && location['region'].toString().isNotEmpty) ? ', ${location['region']}' : ''}'
            : '';

        debugPrint('📍 Resolved location: $locationName');

        return {
          'temp': (current['temp_c'] ?? 0).toDouble(),
          'condition': current['condition']?['text'] ?? 'Unknown',
          'icon': _ensureHttps(current['condition']?['icon'] ?? ''),
          'rainChance': (json['forecast']?['forecastday'] != null && json['forecast']['forecastday'].isNotEmpty)
              ? (json['forecast']['forecastday'][0]['day']['daily_chance_of_rain'] ?? 0).toInt()
              : 0,
          'humidity': (current['humidity'] ?? 0).toInt(),
          'windKph': (current['wind_kph'] ?? 0).toDouble(),
          'locationName': locationName,
        };
      } else if (response.statusCode == 400) {
        throw Exception('City not found.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Weather API key invalid or unauthorized.');
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in getCurrentWeather: $e');
      rethrow;
    }
  }

  /// Fetch current weather using coordinates (lat,lon)
  Future<Map<String, dynamic>> getCurrentWeatherByCoords(double lat, double lon) async {
    try {
      final String url = '$baseUrl/current.json?key=$apiKey&q=${lat.toString()},${lon.toString()}&aqi=no';
      debugPrint('📡 WeatherAPI current (coords) call: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Weather API request timeout'),
      );

      _logResponse('Direct API call (Current - coords)', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final current = json['current'];
        final location = json['location'];

        final String locationName = location != null
            ? '${location['name'] ?? ''}${(location['region'] != null && location['region'].toString().isNotEmpty) ? ', ${location['region']}' : ''}'
            : '';

        debugPrint('📍 Resolved location (coords): $locationName');

        return {
          'temp': (current['temp_c'] ?? 0).toDouble(),
          'condition': current['condition']?['text'] ?? 'Unknown',
          'icon': _ensureHttps(current['condition']?['icon'] ?? ''),
          'rainChance': (json['forecast']?['forecastday'] != null && json['forecast']['forecastday'].isNotEmpty)
              ? (json['forecast']['forecastday'][0]['day']['daily_chance_of_rain'] ?? 0).toInt()
              : 0,
          'humidity': (current['humidity'] ?? 0).toInt(),
          'windKph': (current['wind_kph'] ?? 0).toDouble(),
          'locationName': locationName,
        };
      } else if (response.statusCode == 400) {
        throw Exception('Location not found.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Weather API key invalid or unauthorized.');
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in getCurrentWeatherByCoords: $e');
      rethrow;
    }
  }

  /// Fetch 7-day forecast using coordinates (lat,lon)
  Future<List<WeatherForecast>> getWeatherForecastByCoords(double lat, double lon) async {
    try {
      final String url = '$baseUrl/forecast.json?key=$apiKey&q=${lat.toString()},${lon.toString()}&days=7&aqi=no&alerts=no';
      debugPrint('📡 WeatherAPI forecast (coords) call: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Weather API request timeout'),
      );

      _logResponse('Direct API call (Forecast - coords)', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> forecastDays = json['forecast']?['forecastday'] ?? [];

        return forecastDays.map((day) {
          final dateStr = day['date'] ?? '';
          final condition = day['day']?['condition']?['text'] ?? 'Unknown';
          final iconUrl = _ensureHttps(day['day']?['condition']?['icon'] ?? '');

          return WeatherForecast(
            date: dateStr,
            dayName: WeatherForecast.getDayName(dateStr),
            condition: condition,
            iconUrl: iconUrl,
            maxTempC: (day['day']?['maxtemp_c'] ?? 0).toDouble(),
            minTempC: (day['day']?['mintemp_c'] ?? 0).toDouble(),
            rainChance: (day['day']?['daily_chance_of_rain'] ?? 0).toInt(),
          );
        }).toList();
      } else if (response.statusCode == 400) {
        throw Exception('Location not found.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Weather API key invalid or unauthorized.');
      } else {
        throw Exception('Failed to fetch forecast: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in getWeatherForecastByCoords: $e');
      rethrow;
    }
  }

  /// Fetch 7-day forecast using WeatherAPI
  Future<List<WeatherForecast>> getWeatherForecast(String cityName) async {
    try {
      final String url = '$baseUrl/forecast.json?key=$apiKey&q=${Uri.encodeComponent(cityName)}&days=7&aqi=no&alerts=no';
      debugPrint('📡 WeatherAPI forecast call: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Weather API request timeout'),
      );

      _logResponse('Direct API call (Forecast)', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> forecastDays = json['forecast']?['forecastday'] ?? [];

        return forecastDays.map((day) {
          final dateStr = day['date'] ?? '';
          final condition = day['day']?['condition']?['text'] ?? 'Unknown';
          final iconUrl = _ensureHttps(day['day']?['condition']?['icon'] ?? '');

          return WeatherForecast(
            date: dateStr,
            dayName: WeatherForecast.getDayName(dateStr),
            condition: condition,
            iconUrl: iconUrl,
            maxTempC: (day['day']?['maxtemp_c'] ?? 0).toDouble(),
            minTempC: (day['day']?['mintemp_c'] ?? 0).toDouble(),
            rainChance: (day['day']?['daily_chance_of_rain'] ?? 0).toInt(),
          );
        }).toList();
      } else if (response.statusCode == 400) {
        throw Exception('City not found.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Weather API key invalid or unauthorized.');
      } else {
        throw Exception('Failed to fetch forecast: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in getWeatherForecast: $e');
      rethrow;
    }
  }

  void _logResponse(String method, http.Response response) {
    debugPrint('📊 $method Response: status=${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('   Body: ${response.body}');
    }
  }

  String _ensureHttps(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
    return url;
  }
}
