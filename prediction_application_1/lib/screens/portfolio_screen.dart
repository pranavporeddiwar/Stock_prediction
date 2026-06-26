import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/portfolio_service.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<PortfolioService>(context);
    final isProfitable = service.overallPnL >= 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("NEURAL PORTFOLIO HOLDINGS", 
          style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF9D4EDD)),
            onPressed: () => _openAddPositionDialog(context, service),
          )
        ],
      ),
      body: Column(
        children: [
          // 📊 Unified Metrics Panel Card
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F111A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PORTFOLIO VALUE", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text("₹${service.overallValue.toStringAsFixed(2)}", 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("REAL-TIME P&L", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      "${isProfitable ? '+' : ''}₹${service.overallPnL.toStringAsFixed(2)} (${service.overallPnLPercentage.toStringAsFixed(2)}%)", 
                      style: TextStyle(
                        color: isProfitable ? const Color(0xFF00FFA3) : Colors.redAccent, 
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace'
                      )
                    ),
                  ],
                )
              ],
            ),
          ),

          // 📈 Interactive Owned Asset Ledger Lists
          Expanded(
            child: service.ownedStocks.isEmpty
                ? const Center(child: Text("No monitored assets added to memory yet.", style: TextStyle(color: Colors.white24, fontSize: 11)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: service.ownedStocks.length,
                    itemBuilder: (context, index) {
                      final asset = service.ownedStocks[index];
                      final assetProfit = asset.totalProfitLoss >= 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(asset.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text("${asset.quantity} Units @ ₹${asset.averageBuyPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹${asset.currentLivePrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  "${assetProfit ? '+' : ''}₹${asset.totalProfitLoss.toStringAsFixed(2)} (${asset.profitLossPercentage.toStringAsFixed(2)}%)",
                                  style: TextStyle(color: assetProfit ? const Color(0xFF00FFA3) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openAddPositionDialog(BuildContext context, PortfolioService service) {
    final symController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: const Text("Track Owned Stock Asset", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: symController, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Stock Ticker Symbol (e.g. INFY)", labelStyle: TextStyle(color: Colors.white38))),
            TextField(controller: qtyController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Quantity Units Purchased", labelStyle: TextStyle(color: Colors.white38))),
            TextField(controller: priceController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Average Cost Price Paid (₹)", labelStyle: TextStyle(color: Colors.white38))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abort", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B2CBF)),
            onPressed: () {
              service.addPosition(
                symController.text,
                int.tryParse(qtyController.text) ?? 0,
                double.tryParse(priceController.text) ?? 0.0,
              );
              Navigator.pop(context);
            },
            child: const Text("Link Asset", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}