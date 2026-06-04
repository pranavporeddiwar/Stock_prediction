import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class InvestmentAnalysisPage extends StatelessWidget {
  final StockData data;
  final double investmentAmount;

  const InvestmentAnalysisPage({
    super.key,
    required this.data,
    required this.investmentAmount,
  });

  @override
  Widget build(BuildContext context) {
    double effectivePrice = data.currentPrice > 0 ? data.currentPrice : 1.0;
    int shares = (data.currentPrice > 0 && investmentAmount > 0)
        ? (investmentAmount / effectivePrice).floor()
        : 0;

    double totalCost = shares * effectivePrice;
    double stopLossPrice = data.stopLoss;
    double targetPrice = data.targetPrice;
    double totalRisk = shares * (effectivePrice - stopLossPrice).abs();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "CAPITAL ANALYSIS",
          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const SizedBox(height: 25),
            _buildDataCard("QUANTITY TO ACQUIRE", "$shares UNITS", Icons.shopping_cart_outlined, const Color(0xFF00FFA3)),
            _buildDataCard("DEPLOYMENT CAPITAL", "₹${totalCost.toStringAsFixed(2)}", Icons.account_balance_wallet_outlined, Colors.white),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildMiniCard("STOP LOSS (EXIT)", "₹${stopLossPrice.toStringAsFixed(2)}", Colors.redAccent)),
                const SizedBox(width: 15),
                Expanded(child: _buildMiniCard("TARGET (PROFIT)", "₹${targetPrice.toStringAsFixed(2)}", const Color(0xFF00FFA3))),
              ],
            ),
            const SizedBox(height: 35),
            _buildRiskVerdict(totalRisk),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(width: 25),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(value, style: TextStyle(color: accentColor, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color.withOpacity(0.6), fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRiskVerdict(double risk) {
    bool highRisk = risk > (investmentAmount * 0.03); // Flagging if risk > 3%
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: highRisk ? const Color(0x1AFF5252) : const Color(0x1A00FFA3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: highRisk ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF00FFA3).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(highRisk ? Icons.warning_amber_rounded : Icons.verified_user_outlined, color: highRisk ? Colors.redAccent : const Color(0xFF00FFA3), size: 30),
          const SizedBox(height: 15),
          Text(highRisk ? "EXPOSURE ALERT" : "RISK CLEARANCE GRANTED", style: TextStyle(color: highRisk ? Colors.redAccent : const Color(0xFF00FFA3), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            "Neural assessment shows a total loss potential of ₹${risk.toStringAsFixed(2)}. Ensure this fits your daily drawdown limits.", 
            textAlign: TextAlign.center, 
            style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.6)
          ),
        ],
      ),
    );
  }
}