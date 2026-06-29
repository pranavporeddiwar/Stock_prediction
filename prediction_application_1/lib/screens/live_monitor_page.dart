import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'stock_prediction_screen.dart';
class LiveMonitorPage extends StatefulWidget {
  const LiveMonitorPage({super.key});
  @override
  State<LiveMonitorPage> createState() => _LiveMonitorPageState();
}
class _LiveMonitorPageState extends State<LiveMonitorPage> {
  List<dynamic> stocks = [];
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetchMarketData();
  }
  Future<void> _fetchMarketData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final result = await ApiService().getWatchlistOverview();
      if (mounted) {
        setState(() {
          stocks = result;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stream Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "LIVE NEURAL MONITOR",
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            onPressed: _fetchMarketData,
            icon: const Icon(Icons.sync_problem_rounded, color: Color(0xFF00FFA3), size: 18),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3), strokeWidth: 2))
          : stocks.isEmpty
              ? _buildNoDataState()
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: stocks.length,
                  itemBuilder: (context, i) {
                    final s = stocks[i];
                    final String symbol = s['symbol']?.toString() ?? "N/A";
                    final double ltp = (s['price'] ?? 0.0).toDouble();
                    final double target = (s['target'] ?? 0.0).toDouble();
                    final String signal = s['signal']?.toString() ?? "NEUTRAL";
                    final String confidence = s['confidence']?.toString() ?? "0%";
                    final bool isBullish = signal == "BUY";
                    return _buildLiveStockCard(symbol, ltp, target, signal, confidence, isBullish);
                  },
                ),
    );
  }
  Widget _buildLiveStockCard(String sym, double price, double tar, String sig, String conf, bool isUp) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockPredictionScreen(symbol: sym))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUp ? const Color(0xFF00FFA3).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sym, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("TARGET: ₹${tar.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${price.toStringAsFixed(1)}",
                  style: TextStyle(color: isUp ? const Color(0xFF00FFA3) : Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text("CONFIDENCE: $conf", style: const TextStyle(color: Colors.white12, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white10, size: 40),
          const SizedBox(height: 10),
          const Text("Neural Engine Offline", style: TextStyle(color: Colors.white24, fontSize: 11)),
          TextButton(onPressed: _fetchMarketData, child: const Text("Reconnect", style: TextStyle(color: Color(0xFF00FFA3)))),
        ],
      ),
    );
  }
}
