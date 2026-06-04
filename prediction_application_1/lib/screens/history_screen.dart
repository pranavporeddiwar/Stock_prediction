import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "PREDICTION HISTORY",
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: 8, // Placeholder for logged trades
        itemBuilder: (context, index) {
          return _buildHistoryItem(index);
        },
      ),
    );
  }

  Widget _buildHistoryItem(int index) {
    // Mock data for visual perfection
    bool isWin = index % 2 == 0; 
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("RELIANCE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text("Executed: May 08, 2026", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("₹2,980.50", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isWin ? const Color(0xFF00FFA3) : Colors.redAccent).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isWin ? "PROFIT +3.2%" : "LOSS -1.1%",
                  style: TextStyle(
                    color: isWin ? const Color(0xFF00FFA3) : Colors.redAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}