import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  final now = DateTime.now();
  final expiryDate = DateTime(2026, 4, 9); // 10 days from 2026-03-30
  
  if (now.isAfter(expiryDate)) {
    runApp(const ExpiryApp());
  } else {
    runApp(const AttendanceApp());
  }
}

class ExpiryApp extends StatelessWidget {
  const ExpiryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'please download the updated app',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
