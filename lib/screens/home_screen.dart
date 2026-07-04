import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/feature_card.dart';
import '../widgets/welcome_header.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'schedule_screen.dart';
import 'weather_forecast_screen.dart';
import 'garden_design_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';

import '../services/auth_service.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  late Future<Map<String, dynamic>> _currentWeatherFuture;
  late Future<_HomeStats> _homeStatsFuture;
  final String _defaultCity = 'Faisalabad';
  bool _askedForLocation = false;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentWeatherFuture = _weatherService.getCurrentWeather(_defaultCity);
    _homeStatsFuture = _fetchHomeStats();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskForLocation());
  }

  Future<void> _maybeAskForLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _getLocationAndUpdateWeather();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('has_asked_location') ?? false;

    if (hasAsked || _askedForLocation) {
      await _getLocationAndUpdateWeather();
      return;
    }

    _askedForLocation = true;
    await prefs.setBool('has_asked_location', true);

    await _getLocationAndUpdateWeather();
  }

  Future<void> _getLocationAndUpdateWeather() async {
    try {
      debugPrint('HomeScreen: Resolving location for weather');
      final locationQuery = await _locationService.getCurrentLocationString();

      if (!mounted) return;
      setState(() {
        _currentWeatherFuture =
            _weatherService.getCurrentWeather(locationQuery);
      });
      debugPrint('HomeScreen: Updated weather with location: $locationQuery');
    } catch (e, st) {
      debugPrint('HomeScreen: Failed to resolve location for weather: $e');
      debugPrint('HomeScreen: Stack trace: $st');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not get location. Showing default city weather.'),
            duration: Duration(seconds: 5),
          ),
        );
        setState(() {
          _currentWeatherFuture =
              _weatherService.getCurrentWeather(_defaultCity);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userName = authService.currentUser?.displayName ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0 ? 'Welcome, $userName!' : _getTabTitle(_currentTabIndex),
        ),
        backgroundColor: const Color(0xFF447804),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF447804),
              unselectedItemColor: Colors.grey[600],
              currentIndex: _currentTabIndex,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Scan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Schedule',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTabIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return ScanScreen(initialIndex: 0, showAppBar: false);
      case 2:
        return ScheduleScreen(showAppBar: false);
      case 3:
        return ProfileScreen(showAppBar: false);
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header and Weather in a single sliver box
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildWelcomeHeader(),
                _buildWeatherWidget(),
              ],
            ),
          ),

          // Features Grid
          SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  FeatureCard(
                    icon: Icons.health_and_safety,
                    title: 'Disease Detection',
                    description: 'AI-powered plant health analysis',
                    gradientColors: [Color(0xFF447804), Color(0xFF346E05)],
                    iconColor: Color(0xFFEEFB8F),
                    onTap: () => setState(() => _currentTabIndex = 1),
                  ),
                  FeatureCard(
                    icon: Icons.bug_report,
                    title: 'Pest Detection',
                    description: 'Identify and treat garden pests',
                    gradientColors: [Color(0xFF8FB25C), Color(0xFF447804)],
                    iconColor: Colors.white,
                    onTap: () => setState(() => _currentTabIndex = 1),
                  ),
                  FeatureCard(
                    icon: Icons.water_drop,
                    title: 'Smart Care',
                    description: 'Weather-based care schedules',
                    gradientColors: [Color(0xFF346E05), Color(0xFF243C07)],
                    iconColor: Color(0xFFEEFB8F),
                    onTap: () => setState(() => _currentTabIndex = 2),
                  ),
                  FeatureCard(
                    icon: Icons.park,
                    title: 'Garden Design',
                    description: 'AI-powered layout planning',
                    gradientColors: [Color(0xFFEEFB8F), Color(0xFF8FB25C)],
                    iconColor: Color(0xFF243C07),
                    onTap: _openGardenDesign,
                  ),
                  FeatureCard(
                    icon: Icons.history,
                    title: 'Health History',
                    description: 'Track plant health over time',
                    gradientColors: [Color(0xFF8FB25C), Color(0xFF346E05)],
                    iconColor: Colors.white,
                    onTap: _openHealthHistory,
                  ),
                  FeatureCard(
                    icon: Icons.notifications,
                    title: 'Weather Alerts',
                    description: 'Real-time garden protection',
                    gradientColors: [Color(0xFF447804), Color(0xFF243C07)],
                    iconColor: Color(0xFFEEFB8F),
                    onTap: _openWeatherAlerts,
                  ),
                ],
              ),
            ),

            // Bottom padding for easier scrolling
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      );
    }

  Widget _buildWelcomeHeader() {
    return FutureBuilder<_HomeStats>(
      future: _homeStatsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const _HomeStats();
        return WelcomeHeader(
          plants: stats.plants,
          healthy: stats.healthy,
          needsCare: stats.needsCare,
        );
      },
    );
  }

  Future<_HomeStats> _fetchHomeStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _HomeStats();

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('plants')
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pest_history')
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('disease_history')
            .get(),
      ]);

      final pestHistory = results[1] as QuerySnapshot;
      final diseaseHistory = results[2] as QuerySnapshot;

      int healthy = 0;
      final merged = <Map<String, dynamic>>[
        ...pestHistory.docs
            .map((e) => e.data() as Map<String, dynamic>),
        ...diseaseHistory.docs
            .map((e) => e.data() as Map<String, dynamic>),
      ];

      for (final item in merged) {
        final predicted = (item['predicted_class'] ??
                item['pest_name'] ??
                item['detected_pest'] ??
                item['label'] ??
                '')
            .toString()
            .toLowerCase();
        final report =
            (item['report'] ?? item['advice'] ?? item['ai_advice'] ?? '')
                .toString()
                .toLowerCase();
        if (predicted.contains('healthy') || report.contains('healthy')) {
          healthy++;
        }
      }

      final totalScans = merged.length;
      final needsCare = (totalScans - healthy).clamp(0, totalScans).toInt();
      return _HomeStats(
        plants: (results[0] as QuerySnapshot).docs.length,
        healthy: healthy,
        needsCare: needsCare,
      );
    } catch (_) {
      return const _HomeStats();
    }
  }

  void _refreshHomeStats() {
    if (!mounted) return;
    setState(() {
      _homeStatsFuture = _fetchHomeStats();
    });
  }

  Widget _buildWeatherWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _currentWeatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF447804), Color(0xFF346E05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            );
          } else if (snapshot.hasData) {
            final weather = snapshot.data!;
            final String locationName = (weather['locationName'] is String &&
                    (weather['locationName'] as String).isNotEmpty)
                ? weather['locationName'] as String
                : _defaultCity;
            final rainChance = weather['rainChance'] as int;
            final isHighRain = rainChance > 60;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WeatherForecastScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHighRain
                        ? const [
                            Color.fromARGB(255, 0, 116, 204),
                            Color.fromARGB(255, 0, 76, 153),
                          ]
                        : const [Color(0xFF447804), Color(0xFF346E05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Weather Icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          isHighRain ? Icons.cloud_queue : Icons.wb_sunny,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Weather Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(weather['temp'] as double).toStringAsFixed(1)}°C - ${weather['condition']}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.water_drop,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Rain: $rainChance%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isHighRain) const SizedBox(width: 8),
                              if (isHighRain)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow[600],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'High Rain',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tap to See More
                    const Column(
                      children: [
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '7-day',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber[700]!, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.amber, size: 28),
                  const SizedBox(height: 8),
                  const Text(
                    'Weather unavailable',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentWeatherFuture =
                            _weatherService.getCurrentWeather(_defaultCity);
                      });
                    },
                  ),
                ],
              ),
            );
          } else {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const SizedBox(
                height: 80,
                child: Center(
                  child: Text('Unable to load weather'),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _openHealthHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    ).then((_) => _refreshHomeStats());
  }

  void _openGardenDesign() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GardenDesignScreen()),
    ).then((_) => _refreshHomeStats());
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return 'Scan Plant';
      case 2:
        return 'Care Schedule';
      case 3:
        return 'Profile';
      default:
        return 'GrowLens';
    }
  }

  void _openWeatherAlerts() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _currentWeatherFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF447804)),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.warning_amber, color: Colors.orange),
                        title: Text(
                          'Weather alerts unavailable right now.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Please try again in a moment.'),
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
                  );
                }

                final weather = snapshot.data!;
                final locationName =
                    (weather['locationName'] as String?)?.trim().isNotEmpty ==
                            true
                        ? weather['locationName'] as String
                        : _defaultCity;
                final condition = weather['condition']?.toString() ?? 'Unknown';
                final rainChance = (weather['rainChance'] as int?) ?? 0;
                final humidity = (weather['humidity'] as int?) ?? 0;
                final windKph = (weather['windKph'] as double?) ?? 0;
                final tips = _buildWeatherAlertsTips(
                  condition: condition,
                  rainChance: rainChance,
                  humidity: humidity,
                  windKph: windKph,
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active,
                            color: Color(0xFF447804)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Weather Alerts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF243C07),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$locationName - $condition',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F8E8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDDE6BC)),
                          ),
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (_) => const WeatherForecastScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cloud),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF447804),
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Open 7-Day Forecast'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<String> _buildWeatherAlertsTips({
    required String condition,
    required int rainChance,
    required int humidity,
    required double windKph,
  }) {
    final tips = <String>[];

    if (rainChance >= 70) {
      tips.add(
        'High rain chance ($rainChance%). Skip watering and protect pots from waterlogging.',
      );
    } else if (rainChance >= 40) {
      tips.add(
        'Moderate rain chance ($rainChance%). Reduce watering amount and monitor soil moisture.',
      );
    } else {
      tips.add(
          'Low rain chance ($rainChance%). Continue regular watering schedule.');
    }

    if (humidity >= 80) {
      tips.add(
        'Humidity is high ($humidity%). Improve airflow to reduce fungal disease risk.',
      );
    } else if (humidity <= 35) {
      tips.add(
        'Air is dry ($humidity%). Mist humidity-loving plants and avoid midday sun stress.',
      );
    }

    if (windKph >= 25) {
      tips.add(
        'Wind speed is elevated (${windKph.toStringAsFixed(1)} kph). Move delicate plants to sheltered spots.',
      );
    }

    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('storm') ||
        lowerCondition.contains('thunder')) {
      tips.add(
        'Storm conditions detected. Keep plants indoors or under sturdy cover where possible.',
      );
    } else if (lowerCondition.contains('sunny') ||
        lowerCondition.contains('clear')) {
      tips.add(
          'Clear weather expected. Best time for pruning and morning fertilizing.');
    }

    return tips;
  }
}

class _HomeStats {
  final int plants;
  final int healthy;
  final int needsCare;

  const _HomeStats({
    this.plants = 0,
    this.healthy = 0,
    this.needsCare = 0,
  });
}
