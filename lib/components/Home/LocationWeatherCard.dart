import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/theme_provider.dart';
import '/l10n/app_localizations.dart';

class LocationWeatherCard extends StatelessWidget {
  final String location;
  final String weather;
  final int degree;

  const LocationWeatherCard({
    super.key,
    this.location = "Unknown Location",
    this.weather = "Loading...",
    this.degree = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    final gradient = LinearGradient(
      colors: isDarkMode
          ? [const Color(0xFF3D3F4B), const Color(0xFF2C2E39)]
          : [const Color(0xFF4080FF), const Color(0xFF4080FF).withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.4) : Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            // Left: Weather Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('weather_in'),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.85),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    location,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weather,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFFFFC107),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Right: Icon + Degree
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.orangeAccent, Colors.yellowAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    _getWeatherIcon(weather),
                    size: 30,
                    color: Colors.white,
                    semanticLabel: _getWeatherSemanticLabel(weather),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$degree°C',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(String weather) {
    final w = weather.toLowerCase();

    // Thunder / storm keywords
    if (w.contains('thunder') || w.contains('storm') || w.contains('lightning')) {
      return Icons.flash_on; // shows lightning
    }

    // Rain / drizzle / shower
    if (w.contains('rain') || w.contains('drizzle') || w.contains('shower')) {
      return Icons.beach_access; // umbrella / rain-ish icon
    }

    // Snow / sleet / ice
    if (w.contains('snow') || w.contains('sleet') || w.contains('ice') || w.contains('flurr')) {
      return Icons.ac_unit;
    }

    // Clear sky / sunny
    if (w.contains('clear') || w.contains('sunny')) {
      return Icons.wb_sunny;
    }

    // Partly / mostly cloudy
    if (w.contains('partly') || w.contains('mostly') || w.contains('scattered')) {
      return Icons.wb_cloudy;
    }

    // Generic cloud cases
    if (w.contains('cloud')) {
      return Icons.cloud;
    }

    // Fog / mist / haze / smoke
    if (w.contains('mist') || w.contains('fog') || w.contains('haze') || w.contains('smoke')) {
      return Icons.blur_on;
    }

    // Windy
    if (w.contains('wind') || w.contains('breeze')) {
      return Icons.air;
    }

    // Default unknown
    return Icons.help_outline;
  }

  String _getWeatherSemanticLabel(String weather) {
    final w = weather.trim();
    if (w.isEmpty) return 'weather';
    return w;
  }
}
