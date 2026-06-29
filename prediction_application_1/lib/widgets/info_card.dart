  import 'package:flutter/material.dart';
  class InfoCard extends StatelessWidget {
    final String title;
    final String value;
    final Color color;
    const InfoCard({super.key, required this.title, required this.value, required this.color});
    @override
    Widget build(BuildContext context) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      );
    }
  }
