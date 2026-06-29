import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("Uplink required to view ledger.", style: TextStyle(color: Colors.white54))),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("AI PERFORMANCE JOURNAL", style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('ai_journal')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3)));
          }
          if (snapshot.hasError) {
            return const Center(child: Text(" Matrix sync error.", style: TextStyle(color: Colors.redAccent)));
          }
          final docs = snapshot.data?.docs ?? [];
          List<Map<String, dynamic>> trades = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            String dateStr = 'Unknown Date';
            if (data['timestamp'] != null) {
              Timestamp ts = data['timestamp'];
              dateStr = DateFormat('MMM dd, yyyy HH:mm').format(ts.toDate());
            }
            return {
              'symbol': data['symbol'] ?? 'UNKNOWN',
              'isWin': data['isWin'] ?? false,
              'date': dateStr,
            };
          }).toList();
          int wins = trades.where((t) => t['isWin'] == true).length;
          double winRate = trades.isEmpty ? 0 : (wins / trades.length) * 100;
          return Column(
            children: [
              _buildStatsHeader(trades.length, winRate),
              Expanded(
                child: trades.isEmpty
                  ? const Center(child: Text("No trades logged yet.", style: TextStyle(color: Colors.white24)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: trades.length,
                      itemBuilder: (context, index) {
                        return _buildTradeTile(trades[index]);
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
  Widget _buildStatsHeader(int totalTrades, double winRate) {
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
          _statItem("TOTAL TRADES", "$totalTrades"),
          _statItem("WIN RATE", "${winRate.toStringAsFixed(1)}%"),
          _statItem("SUCCESS", winRate >= 50 ? "PRO" : "LEARNING"),
        ],
      ),
    );
  }
  Widget _statItem(String l, String v) => Column(
    children: [
      Text(l, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
      Text(v, style: const TextStyle(color: const Color(0xFF00FFA3), fontSize: 18, fontWeight: FontWeight.bold)),
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
