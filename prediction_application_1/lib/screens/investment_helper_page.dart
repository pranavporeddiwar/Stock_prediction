import 'package:flutter/material.dart';
import '../models/stock_data.dart';
import 'investment_analysis_page.dart';
class InvestmentHelperPage extends StatefulWidget {
  final StockData data;
  const InvestmentHelperPage({super.key, required this.data});
  @override
  State<InvestmentHelperPage> createState() => _InvestmentHelperPageState();
}
class _InvestmentHelperPageState extends State<InvestmentHelperPage> {
  final TextEditingController _capitalController = TextEditingController(text: "10000");
  final double _riskPerTrade = 0.02;
  @override
  Widget build(BuildContext context) {
    double currentPrice = widget.data.currentPrice;
    double targetPrice = widget.data.targetPrice;
    double potentialProfitPct = currentPrice > 0
        ? ((targetPrice - currentPrice) / currentPrice) * 100
        : 0.0;
    double totalCapital = double.tryParse(_capitalController.text) ?? 0;
    double riskAmount = totalCapital * _riskPerTrade;
    double stopLoss = widget.data.stopLoss;
    double riskPerShare = (currentPrice - stopLoss).abs();
    int quantity = riskPerShare > 0 ? (riskAmount / riskPerShare).floor() : 0;
    double totalInvestment = quantity * currentPrice;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("CAPITAL STRATEGY", style: TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPriceOverview(currentPrice, targetPrice, potentialProfitPct),
            const SizedBox(height: 25),
            _buildInputSection(),
            const SizedBox(height: 25),
            _buildResultCard(quantity, totalInvestment, riskAmount),
            const SizedBox(height: 30),
            _buildAdvice(potentialProfitPct),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFA3),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InvestmentAnalysisPage(data: widget.data, investmentAmount: totalInvestment))
                ),
                child: const Text("GENERATE FINAL REPORT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPriceOverview(double cur, double tar, double pct) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _priceCol("ENTRY", cur, Colors.white),
          const Icon(Icons.bolt, color: Color(0xFF00FFA3), size: 16),
          _priceCol("AI TARGET", tar, const Color(0xFF00FFA3)),
          _priceCol("EST. GAIN", pct, const Color(0xFF00FFA3), isPct: true),
        ],
      ),
    );
  }
  Widget _buildInputSection() {
    return TextField(
      controller: _capitalController,
      keyboardType: TextInputType.number,
      onChanged: (val) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        labelText: "TRADING CAPITAL (₹)",
        labelStyle: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1),
        prefixText: "₹ ",
        prefixStyle: TextStyle(color: Colors.white38, fontSize: 20),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFA3))),
      ),
    );
  }
  Widget _buildResultCard(int qty, double total, double risk) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF00FFA3).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text("OPTIMIZED QUANTITY", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text("$qty UNITS", style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: Colors.white10, thickness: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoTile("TOTAL VALUE", "₹${total.toStringAsFixed(0)}"),
              _infoTile("NET RISK (2%)", "₹${risk.toStringAsFixed(0)}"),
            ],
          )
        ],
      ),
    );
  }
  Widget _buildAdvice(double pct) {
    bool isGoodTrade = pct > 1.2 && widget.data.sentiment > 0.55;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGoodTrade ? const Color(0x1400FFA3) : const Color(0x14FFAB40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isGoodTrade ? Colors.greenAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2))
      ),
      child: Row(
        children: [
          Icon(isGoodTrade ? Icons.verified : Icons.warning_amber, color: isGoodTrade ? const Color(0xFF00FFA3) : Colors.orangeAccent, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              isGoodTrade ? "Trade setup verified by Llama-3 reasoning. Stick to stop-loss." : "R/R ratio identified as high risk. Wait for better entry patterns.",
              style: TextStyle(color: isGoodTrade ? Colors.white70 : Colors.orangeAccent.withOpacity(0.8), fontSize: 11, height: 1.5)
            )
          ),
        ],
      ),
    );
  }
  Widget _priceCol(String label, double val, Color color, {bool isPct = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text(isPct ? "${val.toStringAsFixed(2)}%" : "₹${val.toStringAsFixed(1)}",
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
    ]);
  }
  Widget _infoTile(String l, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(l, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
