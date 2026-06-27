import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class SystemStatusIndicator extends StatefulWidget {
  const SystemStatusIndicator({super.key});

  @override
  State<SystemStatusIndicator> createState() => _SystemStatusIndicatorState();
}

class _SystemStatusIndicatorState extends State<SystemStatusIndicator> {
  String status = "checking"; // "operational", "degraded", "checking"

  @override
  void initState() {
    super.initState();
    _pingServer();
  }

  void _pingServer() async {
    try {
      final response = await http.get(Uri.parse("${ApiService.baseUrl}/health-check"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => status = data['status']);
      }
    } catch (e) {
      setState(() => status = "degraded");
    }
  }

  @override
  Widget build(BuildContext context) {
    Color color = status == "operational" ? const Color(0xFF00FFA3) : Colors.redAccent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}