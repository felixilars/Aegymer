import 'package:flutter/material.dart';



// Color Palette
const backgroundColor = Color(0xffF5F7FA);
const cardColor = Colors.white;
const primaryColor = Color(0xff2563EB);
const accentColor = Color(0xffFF6B35);
const textColor = Color(0xff1F2937);
const subtitleColor = Color(0xff6B7280);

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfilePressed;

  const HomeAppBar({super.key, this.onProfilePressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;

    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.account_circle, color: iconColor, size: 28),
        onPressed: onProfilePressed,
      ),
      title: Text(
        'Aegymer',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: iconColor,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: iconColor),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.notifications, color: iconColor),
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}