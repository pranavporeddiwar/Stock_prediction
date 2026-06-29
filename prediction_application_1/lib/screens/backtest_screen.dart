import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
class BacktestScreen extends StatefulWidget {
  final String symbol;
  const BacktestScreen({super.key, required this.symbol});
  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}
class _BacktestScreenState extends State<BacktestScreen> {
  Map<String, dynamic>? report;
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    _runBacktest();
  }
  Future<void> _runBacktest() async {
    try {
      final res = await http.get(Uri.parse("${ApiService.baseUrl}/backtest/${widget.symbol}"));
      if (mounted) setState(() { report = jsonDecode(res.body); isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("${widget.symbol} STRATEGY LAB"), backgroundColor: Colors.black),
      body: isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3)))
        : Column(
            children: [
              _buildMetricCard("NET PROFIT", "₹${report?['net_profit']}"),
              _buildMetricCard("WIN RATE", "${report?['win_rate']}%"),
              Expanded(
                child: ListView.builder(
                  itemCount: report?['trade_log'].length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(report?['trade_log'][i]['type'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text(report?['trade_log'][i]['time'], style: const TextStyle(color: Colors.white24)),
                  ),
                ),
              )
            ],
          ),
    );
  }
  Widget _buildMetricCard(String label, String value) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.all(10),
    color: Colors.white10,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white38)), Text(value, style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 18, fontWeight: FontWeight.bold))]),
  );
}
