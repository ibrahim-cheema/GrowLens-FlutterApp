import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();
  late Future<List<WeatherForecast>> _forecastFuture;
  String _currentCity = 'Faisalabad'; // Default city

  @override
  void initState() {
    super.initState();
    _forecastFuture = _weatherService.getWeatherForecast(_currentCity);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _searchCity() {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      _showErrorSnackBar('Please enter a city name');
      return;
    }

    setState(() {
      _currentCity = city;
      _forecastFuture = _weatherService.getWeatherForecast(city);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('7-Day Weather Forecast'),
        centerTitle: true,
        backgroundColor: const Color(0xFF447804),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        hintText: 'Enter city name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: Color(0xFF447804),
                        ),
                      ),
                      onSubmitted: (_) => _searchCity(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF447804),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: _searchCity,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Forecast List
            FutureBuilder<List<WeatherForecast>>(
              future: _forecastFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF447804)),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No forecast data available');
                }

                final forecasts = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather for $_currentCity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF243C07),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: forecasts.length,
                      itemBuilder: (context, index) {
                        final forecast = forecasts[index];
                        final isHighRainChance = forecast.rainChance > 60;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: isHighRainChance
                                    ? [Colors.blue[50]!, Colors.blue[100]!]
                                    : [Colors.white, Colors.grey[50]!],
                              ),
                            ),
                            child: Row(
                              children: [
                                // Weather Icon
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: forecast.iconUrl.isNotEmpty
                                      ? Image.network(
                                          forecast.iconUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.cloud,
                                              color: Color(0xFF447804),
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons.cloud_queue,
                                          color: Color(0xFF447804),
                                        ),
                                ),
                                const SizedBox(width: 16),

                                // Date and Condition
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${forecast.dayName} - ${forecast.condition}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF243C07),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${forecast.maxTempC.toStringAsFixed(1)}°C / ${forecast.minTempC.toStringAsFixed(1)}°C',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Rain Chance Badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isHighRainChance
                                            ? Colors.blue
                                            : Colors.green,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${forecast.rainChance}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isHighRainChance)
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.water_drop,
                                            color: Colors.blue,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Rain ☔',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Text(
                                        'No rain',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
