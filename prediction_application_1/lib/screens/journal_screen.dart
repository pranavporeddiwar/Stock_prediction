import 'package:flutter/material.dart';
import '../services/journal_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final JournalService _service = JournalService();
  List<Map<String, dynamic>> trades = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final data = await _service.getTrades();
    setState(() => trades = data);
  }

  @override
  Widget build(BuildContext context) {
    int wins = trades.where((t) => t['isWin'] == true).length;
    double winRate = trades.isEmpty ? 0 : (wins / trades.length) * 100;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("AI PERFORMANCE JOURNAL", style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1)),
      ),
      body: Column(
        children: [
          _buildStatsHeader(winRate),
          Expanded(
            child: trades.isEmpty 
              ? const Center(child: Text("No trades logged yet.", style: TextStyle(color: Colors.white24)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: trades.length,
                  itemBuilder: (context, index) {
                    final t = trades[index];
                    return _buildTradeTile(t);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(double winRate) {
    return Container(
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00FFA3).withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF00FFA3).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem("TOTAL TRADES", "${trades.length}"),
          _statItem("WIN RATE", "${winRate.toStringAsFixed(1)}%"),
          _statItem("SUCCESS", winRate >= 50 ? "PRO" : "LEARNING"),
        ],
      ),
    );
  }

  Widget _statItem(String l, String v) => Column(
    children: [
      Text(l, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
      Text(v, style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 18, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildTradeTile(Map<String, dynamic> t) {
    bool isWin = t['isWin'];
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['symbol'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(t['date'], style: const TextStyle(color: Colors.white24, fontSize: 9)),
            ],
          ),
          Text(
            isWin ? "PROFIT" : "LOSS",
            style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
} 