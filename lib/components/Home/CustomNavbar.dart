import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/theme_provider.dart';
import '../../l10n/app_localizations.dart';

class CustomNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavbar({super.key, required this.selectedIndex, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final localizations = AppLocalizations.of(context);
    
    return Container(
      height: 60,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF3D3F4B) : const Color(0xFF4080FF),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(context, FontAwesomeIcons.language, localizations.translate('nav_translator'), 0),
            _buildNavItem(context, FontAwesomeIcons.cube, localizations.translate('nav_camera'), 1),
          _buildNavItem(context, FontAwesomeIcons.house, localizations.translate('nav_home'), 2),
          _buildNavItem(context, FontAwesomeIcons.solidComments, localizations.translate('nav_forum'), 3),
          _buildNavItem(context, FontAwesomeIcons.solidUser, localizations.translate('nav_user'), 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, dynamic icon, String label, int index) {
    final iconColor = selectedIndex == index
        ? const Color(0xCCFFB300)
        : Colors.white70;
    
    final Widget iconWidget = icon is FaIconData
        ? FaIcon(
            icon,
            color: iconColor,
            size: 20,
          )
        : Icon(
            icon,
            color: iconColor,
            size: 20,
          );

    return IconButton(
      icon: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          if (selectedIndex == index)
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 12,
              ),
            ),
        ],
      ),
      onPressed: () {
        if (index == 2) {
          onItemTapped(2);
        } else {
          onItemTapped(index);
        }
      },
      alignment: Alignment.center,
    );
  }
}