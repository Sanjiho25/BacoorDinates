import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language'),
      ),
      body: ListView.builder(
        itemCount: AppLocalizations.supportedLocales.length,
        itemBuilder: (context, index) {
          final locale = AppLocalizations.supportedLocales[index];
          final languageCode = locale.languageCode;
          final countryCode = locale.countryCode;
          final key = countryCode != null ? '${languageCode}_$countryCode' : languageCode;
          final languageName = AppLocalizations.languageNames[key] ?? 'Unknown';          final languageProvider = Provider.of<LanguageProvider>(context);
          return ListTile(
            title: Text(languageName),
            onTap: () {
              Provider.of<LanguageProvider>(context, listen: false).setLocale(locale);
              Navigator.pop(context);
            },
            trailing: Icon(
              languageProvider.currentLocale == locale 
                  ? Icons.check_circle 
                  : null,
              color: Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }
}
