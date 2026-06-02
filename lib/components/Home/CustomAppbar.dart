import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/theme_provider.dart';
import 'package:untitled/providers/notification_provider.dart';

class CustomAppBarExample extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBarExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF3D3F4B) : Colors.white,
      elevation: 2,
      title: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'BACOOR',
              style: TextStyle(
                color: Color(0xFF4080FF), // primary blue
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            TextSpan(
              text: 'DINATES',
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFFFFB300),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
            if (context.watch<NotificationProvider>().hasUnread)
              Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 2, top: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}