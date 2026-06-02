import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/auth_provider.dart' as app_auth;
import 'package:untitled/screens/LoginPage.dart';
import 'package:untitled/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import 'AboutPage.dart';
import 'ChangePasswordPage.dart';
import 'EditProfilePage.dart';
import 'ItineraryScreen.dart';
import 'package:url_launcher/url_launcher.dart';
 

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Widget _buildProfileContent(BuildContext context, DocumentSnapshot snapshot, User user) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    if (!snapshot.exists) {
      return Center(child: Text(localizations.translate('no_profile_data')));
    }

    final data = snapshot.data() as Map<String, dynamic>;
    final username = data['username'] ?? 'A';
    final photoUrl = data['photoURL'] ?? '';

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: isDarkMode ? Colors.grey[800] : const Color(0xFF4080FF).withValues(alpha: 0.1),
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF4080FF),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          username,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.email ?? '',
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('travel_plan'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            context,
            localizations.translate('my_trips'),
            Icons.calendar_month_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ItineraryScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            localizations.translate('account_settings'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            context,
            localizations.translate('edit_profile'),
            Icons.edit,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfilePage()),
            ),
          ),
          _buildSettingCard(
            context,
            localizations.translate('change_password'),
            Icons.lock,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            localizations.translate('app_settings'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            context,
            '${localizations.translate('language')} (${localizations.currentLanguage})',
            Icons.language,
            () => Navigator.pushNamed(context, '/language'),
          ),
          _buildSettingCard(
            context,
            localizations.translate('theme'),
            Icons.palette,
            () => _showThemeDialog(context),
          ),
          _buildSettingCard(
            context,
            localizations.translate('about'),
            Icons.info,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            localizations.translate('emergency_contacts'),
            Icons.local_hospital,
            () => _showEmergencyContacts(context),
          ),
          const SizedBox(height: 24),
          _buildSignOutButton(context),
        ],
      ),
    );
  }

  void _showEmergencyContacts(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final contacts = [
      {'label': 'BDRRMO', 'number': '(046) 417-0727'},
      {'label': 'Philippine National Police-Bacoor City', 'number': '(046) 417-6366'},
      {'label': 'Bureau of Fire Protection-Bacoor City', 'number': '(046) 417-6060'},
      {'label': 'City Information Office', 'number': '(046) 481-4120'},
      {'label': 'Bacoor Emergency Hotline', 'number': '161'},
      {'label': 'Philippines Emergency Hotline', 'number': '911'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                ListTile(
                  title: Text(localizations.translate('emergency_contacts')),
                  subtitle: Text(localizations.translate('select_emergency_contact')),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final c = contacts[index];
                      return ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text('${c['label']}'),
                        subtitle: Text('${c['number']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _callNumber('${c['number']}', context);
                          },
                          tooltip: localizations.translate('call'),
                        ),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _callNumber('${c['number']}', context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _callNumber(String number, BuildContext context) async {
    try {
      final uri = Uri(scheme: 'tel', path: number);
      // Try to launch the tel: URI directly; most devices support this
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).translate('call_failed')}: ${e.toString()}')),
      );
    }
  }

  Widget _buildSignOutButton(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showSignOutDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB300),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(localizations.translate('sign_out')),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.translate('sign_out')),
        content: Text(localizations.translate('sign_out_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<app_auth.AuthProvider>().signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.translate('sign_out')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<app_auth.AuthProvider>().user;
    final localizations = AppLocalizations.of(context);
    
    if (user == null) {
      return const LoginPage();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('profile'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context, user),
            _buildSettingsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User user) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final localizations = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF3D3F4B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(localizations.translate('no_profile_data')));
          }
          return _buildProfileContent(context, snapshot.data!, user);
        },
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final isDarkMode = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      builder: (context) {
        final dialogLocalizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogLocalizations.translate('theme_settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(dialogLocalizations.translate('light_mode')),
                leading: const Icon(Icons.light_mode),
                selected: !isDarkMode,
                selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                onTap: () {
                  if (isDarkMode) {
                    context.read<ThemeProvider>().toggleTheme();
                  }
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(dialogLocalizations.translate('dark_mode')),
                leading: const Icon(Icons.dark_mode),
                selected: isDarkMode,
                selectedTileColor: const Color(0xFF3D3F4B).withValues(alpha: 0.3),
                onTap: () {
                  if (!isDarkMode) {
                    context.read<ThemeProvider>().toggleTheme();
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(dialogLocalizations.translate('close')),
            ),
          ],
        );
      },
    );
  }
}
