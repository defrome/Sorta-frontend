import 'package:flutter/material.dart';

import 'screens/auth/auth_screen.dart';
import 'shared/sorta_colors.dart';
import 'sorta_shell.dart';

void main() {
  runApp(const SortaApp());
}

class SortaApp extends StatelessWidget {
  const SortaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sorta AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: SortaColors.background,
        useMaterial3: true,
      ),
      home: const SortaAuthGate(child: SortaShell()),
    );
  }
}
