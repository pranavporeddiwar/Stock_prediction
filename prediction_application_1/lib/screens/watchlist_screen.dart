import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'stock_prediction_screen.dart';
import 'backtest_screen.dart'; // 🔬 IMPORTED: Link to your Strategy Lab UI

// --- HEARTBEAT WIDGET ---
class SystemStatusIndicator extends StatefulWidget {
  const SystemStatusIndicator({super.key});
  @override
  State<SystemStatusIndicator> createState() => _SystemStatusIndicatorState();
}

class _SystemStatusIndicatorState extends State<SystemStatusIndicator> {
  String status = "checking";
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 30), (_) => _ping());
    _ping();
  }
  Future<void> _ping() async {
    try {
      final res = await http.get(Uri.parse("${ApiService.baseUrl}/health-check"));
      if (mounted) setState(() => status = jsonDecode(res.body)['status']);
    } catch (_) { if (mounted) setState(() => status = "degraded"); }
  }
  @override
  Widget build(BuildContext context) {
    Color col = status == "operational" ? const Color(0xFF00FFA3) : Colors.redAccent;
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(status.toUpperCase(), style: TextStyle(color: col, fontSize: 8, fontWeight: FontWeight.bold))
    ]);
  }
}

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<dynamic> stocks = [];
  List<dynamic> filteredStocks = [];
  bool isLoading = true;
  bool isSearching = false;
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _overlaySearchController = TextEditingController();

  late List<dynamic> _preCalculatedSuggestions;

  final List<String> _allMarketStocks = [
    "ADANIENT", "ASIANPAINT", "AXISBANK", "BAJAJ-AUTO", "BAJFINANCE", 
    "BHARTIARTL", "BPCL", "BRITANNIA", "CIPLA", "COALINDIA", 
    "DIVISLAB", "DRREDDY", "EICHERMOT", "GRASIM", "HCLTECH", 
    "HDFC", "HDFCBANK", "HEROMOTOCO", "HINDALCO", "HINDUNILVR", 
    "ICICIBANK", "INDUSINDBK", "INFY", "ITC", "JSWSTEEL", 
    "KOTAKBANK", "LT", "M&M", "MARUTI", "NESTLEIND", 
    "NTPC", "ONGC", "POWERGRID", "RELIANCE", "SBILIFE", 
    "SBIN", "SUNPHARMA", "TATACONSUM", "TATAMOTORS", "TATASTEEL", 
    "TCS", "TECHM", "TITAN", "ULTRACEMCO", "UPL", "WIPRO"
  ];

  @override
  void initState() {
    super.initState();
    _preCalculatedSuggestions = _allMarketStocks
        .map((s) => {'symbol': s, 'price': 0.0, 'signal': 'VIEW'})
        .toList();
    _loadWatchlist();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isSearching && mounted) _loadWatchlist(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _overlaySearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() {
      isSearching = query.isNotEmpty || FocusScope.of(context).hasFocus;
      filteredStocks = query.isEmpty 
          ? _preCalculatedSuggestions 
          : _preCalculatedSuggestions.where((s) => s['symbol'].toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Future<void> _loadWatchlist({bool isSilent = false}) async {
    if (!mounted || isSearching) return;
    if (!isSilent) setState(() => isLoading = true);
    try {
      final data = await ApiService().getWatchlistOverview();
      if (mounted) setState(() { stocks = data; filteredStocks = data; isLoading = false; });
    } catch (e) {
      debugPrint("❌ Watchlist Sync Error: $e");
      if (mounted && !isSilent) setState(() => isLoading = false);
    }
  }

  // ⚡ UPDATED COMPREHENSIVE SEARCH & BACKTEST OVERLAY MODAL
  void _showComprehensiveSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0F111A), 
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            
            // Search field triggers prediction view immediately on submit
            TextField(
              controller: _overlaySearchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter stock symbol (e.g., RELIANCE)...", 
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.auto_awesome, color: Color(0xFF9D4EDD)), 
                filled: true, 
                fillColor: Colors.black, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => StockPredictionScreen(symbol: query.toUpperCase())));
                }
              },
            ),
            const SizedBox(height: 25),
            
            // Direct Action Trigger Nodes for Search Selection
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D4EDD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.timeline, size: 18),
                    label: const Text("ANALYZE FORECAST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      final symbol = _overlaySearchController.text.trim().toUpperCase();
                      if (symbol.isNotEmpty) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => StockPredictionScreen(symbol: symbol)));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0x1A00FFA3),
                      foregroundColor: const Color(0xFF00FFA3),
                      side: const BorderSide(color: Color(0x3300FFA3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text("RUN BACKTEST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      final symbol = _overlaySearchController.text.trim().toUpperCase();
                      if (symbol.isNotEmpty) {
                        Navigator.pop(context); // Unmount modal overlay safely
                        // 🔬 Routes user immediately to the Strategy Lab screen node
                        Navigator.push(context, MaterialPageRoute(builder: (context) => BacktestScreen(symbol: symbol)));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 35),
            
            const Text(
              "QUICK LAB SUGGESTIONS", 
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 15),
            
            // Interactive Quick Suggestion Row Matrix
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ["RELIANCE", "TCS", "INFY", "SBIN"].map((ticker) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => StockPredictionScreen(symbol: ticker)));
                        },
                        child: Text(ticker, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.science_outlined, color: Color(0xFF00FFA3), size: 16),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BacktestScreen(symbol: ticker)));
                        },
                      )
                    ],
                  ),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Text(isSearching ? "MARKET DISCOVERY" : "AI MARKET MONITOR", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Spacer(),
            if (!isSearching) const SystemStatusIndicator(), 
          ],
        ),
        leading: isSearching ? IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFA3), size: 20), onPressed: () => setState(() => isSearching = false)) : null,
        actions: [
          if (!isSearching) IconButton(icon: const Icon(Icons.manage_search, color: Color(0xFF9D4EDD), size: 26), onPressed: () => _showComprehensiveSearch(context)),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(child: isLoading && stocks.isEmpty ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3))) : _buildWatchlist()),
        ],
      ),
    );
  }

  Widget _buildWatchlist() => ListView.builder(
    physics: const BouncingScrollPhysics(),
    itemCount: filteredStocks.length,
    itemBuilder: (context, i) => _buildStockCard(filteredStocks[i]),
  );

  Widget _buildSearchBox() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
    child: TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(hintText: "Search A-Z Tickers...", prefixIcon: const Icon(Icons.search, color: Color(0xFF00FFA3)), filled: true, fillColor: const Color(0xFF111111), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
    ),
  );

  Widget _buildStockCard(dynamic s) {
    final bool isSuggestion = s['signal'] == 'VIEW';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StockPredictionScreen(symbol: s['symbol']))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: isSuggestion ? Colors.black : const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(24), border: Border.all(color: s['signal'] == 'BUY' ? const Color(0xFF00FFA3).withOpacity(0.15) : Colors.white10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['symbol'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("₹${s['price']}", style: const TextStyle(color: Colors.white38, fontSize: 11))]),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: s['signal'] == 'BUY' ? const Color(0x1A00FFA3) : Colors.white10, borderRadius: BorderRadius.circular(8)), child: Text(s['signal'], style: TextStyle(color: s['signal'] == 'BUY' ? const Color(0xFF00FFA3) : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}