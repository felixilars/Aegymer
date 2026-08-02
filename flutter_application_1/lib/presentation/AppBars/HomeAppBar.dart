import 'package:flutter/material.dart';



// Color Palette
const backgroundColor = Color(0xffF5F7FA);
const cardColor = Colors.white;
const primaryColor = Color(0xff2563EB);
const accentColor = Color(0xffFF6B35);
const textColor = Color(0xff1F2937);
const subtitleColor = Color(0xff6B7280);

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {

  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.account_circle, color: textColor, size: 28),
          onPressed: () {},
        ),
        title: const Text(
          'Aegyme',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: textColor),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: textColor),
            onPressed: () {},
          ),
        ],
      );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}