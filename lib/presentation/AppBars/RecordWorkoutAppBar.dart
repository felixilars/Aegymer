import 'package:flutter/material.dart';

// Color Palette
const backgroundColor = Color(0xffF5F7FA);
const cardColor = Colors.white;
const primaryColor = Color(0xff2563EB);
const accentColor = Color(0xffFF6B35);
const textColor = Color(0xff1F2937);
const subtitleColor = Color(0xff6B7280);

class RecordWorkoutAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback? onHomePressed;

  const RecordWorkoutAppBar({super.key, this.onHomePressed});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'Aegymer Workout',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
