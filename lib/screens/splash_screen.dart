
// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final String? teamAJson = prefs.getString('teamAScores');
      final String? teamBJson = prefs.getString('teamBScores');
      bool hasSavedScores = false;
      if (teamAJson != null) {
        final List<dynamic> decoded = jsonDecode(teamAJson);
        hasSavedScores = decoded.isNotEmpty;
      }
      if (!hasSavedScores && teamBJson != null) {
        final List<dynamic> decoded = jsonDecode(teamBJson);
        hasSavedScores = decoded.isNotEmpty;
      }
      Navigator.pushReplacementNamed(
        context,
        hasSavedScores ? '/game' : '/home',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Using the new image as background for the splash screen with a color filter
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/image/splash.png'), // Updated to .png
                fit: BoxFit.cover, // Cover the entire container
                colorFilter: ColorFilter.mode(
                  Color.fromARGB((255 * 0.5).round(), 0, 0, 0), // Darker overlay
                  BlendMode.darken,
                ),
              ),
            ),
            // No text or progress indicator as per previous request
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x88000000)
                      : const Color(0x33FFFFFF),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xCC000000)
                      : const Color(0x66FFFFFF),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
