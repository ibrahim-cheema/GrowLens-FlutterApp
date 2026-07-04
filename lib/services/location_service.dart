import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  /// Fetches the user's current location and returns it as a formatted string.
  /// Tries to return "City, Country" address.
  /// Falls back to lat,long if address lookup fails.
  Future<String> getCurrentLocationString() async {
    try {
      debugPrint('LocationService: Checking location permission...');
      await _ensureLocationPermission();

      final position = await _resolveBestPosition();
      debugPrint(
        'LocationService: Obtained position lat=${position.latitude}, lon=${position.longitude}',
      );

      try {
        return await _getAddressFromPosition(position);
      } catch (e) {
        debugPrint('LocationService: Failed to resolve address: $e');
        return '${position.latitude},${position.longitude}';
      }
    } catch (e) {
      debugPrint('LocationService: Failed to get location: $e');
      if (e is TimeoutException || e.toString().contains('TimeoutException')) {
        final approximateLocation = await _getApproximateLocationFromIp();
        if (approximateLocation != null) {
          return approximateLocation;
        }
        throw Exception('Location request timed out. Please retry.');
      }
      if (e.toString().contains('Location services are disabled')) {
        throw Exception('Location services are disabled');
      }
      if (e.toString().contains('denied')) {
        throw Exception('Location permission denied');
      }
      rethrow;
    }
  }

  Future<void> _ensureLocationPermission() async {
    // On web this can be unreliable depending on browser support, so skip this gate there.
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('LocationService: Current permission: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('LocationService: Permission denied, requesting...');
      permission = await Geolocator.requestPermission();
      debugPrint('LocationService: After request, permission: $permission');
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable it in settings.',
      );
    }
  }

  Future<Position> _resolveBestPosition() async {
    Position? lastKnownPosition;
    try {
      lastKnownPosition = await Geolocator.getLastKnownPosition();
    } catch (e) {
      // Some platforms/browsers may not provide cached locations.
      debugPrint('LocationService: Last known position unavailable: $e');
    }

    if (lastKnownPosition != null) {
      debugPrint('LocationService: Using last known position');
      return lastKnownPosition;
    }

    try {
      debugPrint('LocationService: Requesting fresh position (attempt 1)');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 30),
      );
    } catch (e) {
      debugPrint('LocationService: Attempt 1 failed: $e');
    }

    try {
      debugPrint('LocationService: Requesting fresh position (attempt 2)');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('LocationService: Attempt 2 failed: $e');
    }

    throw TimeoutException('Unable to resolve current position in time.');
  }

  /// Converts position to address string
  Future<String> _getAddressFromPosition(Position position) async {
    if (kIsWeb) {
      // Use OpenStreetMap Nominatim API for Web
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1',
        );

        final response = await http.get(
          url,
          headers: {'User-Agent': 'GrowLens_App/1.0'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'];

          String? city =
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'];
          String? country = address['country'];

          if (city != null && country != null) {
            return '$city, $country';
          } else if (data['display_name'] != null) {
            final displayName = data['display_name'] as String;
            final parts = displayName.split(', ');
            if (parts.length >= 2) {
              return '${parts[0]}, ${parts.last}';
            }
            return displayName;
          }
        }
      } catch (e) {
        debugPrint('LocationService: Web geocoding failed: $e');
      }
    } else {
      // Use standard geocoding plugin for Mobile
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          final parts = <String>[];

          if (place.locality != null && place.locality!.isNotEmpty) {
            parts.add(place.locality!);
          } else if (place.subAdministrativeArea != null &&
              place.subAdministrativeArea!.isNotEmpty) {
            parts.add(place.subAdministrativeArea!);
          }

          if (place.country != null && place.country!.isNotEmpty) {
            parts.add(place.country!);
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      } catch (e) {
        debugPrint('LocationService: Mobile geocoding failed: $e');
      }
    }

    // Fallback if geocoding fails
    return '${position.latitude},${position.longitude}';
  }

  /// Fetches the user's current location and returns Position object
  Future<Position> getCurrentPosition() async {
    try {
      await _ensureLocationPermission();
      return await _resolveBestPosition();
    } catch (e) {
      debugPrint('LocationService: Failed to get position: $e');
      rethrow;
    }
  }

  /// Formats a Position object to a readable string
  String formatPosition(Position position) {
    return '${position.latitude},${position.longitude}';
  }

  /// Approximate location by IP without relying on location permission.
  Future<String?> getApproximateLocationString() async {
    return _getApproximateLocationFromIp();
  }

  Future<String?> _getApproximateLocationFromIp() async {
    try {
      debugPrint('LocationService: Trying IP-based location fallback');
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final city = (data['city'] ?? '').toString().trim();
      final country = (data['country_name'] ?? '').toString().trim();

      if (city.isNotEmpty && country.isNotEmpty) {
        return '$city, $country';
      }
      if (country.isNotEmpty) {
        return country;
      }
      return null;
    } catch (e) {
      debugPrint('LocationService: IP fallback failed: $e');
      return null;
    }
  }
}
