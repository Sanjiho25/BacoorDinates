import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/theme_provider.dart';

import '../../screens/SearchPage.dart';
import '../../l10n/app_localizations.dart';

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      },
      child: AbsorbPointer(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search'),
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              suffixIcon: const Icon(
                Icons.search,
                color: Color(0xFF4080FF),
              ),
              filled: isDarkMode,
              fillColor: isDarkMode ? const Color(0xFF3D3F4B).withValues(alpha: 0.7) : null,
            ),
          ),
        ),
      ),
    );
  }
}
