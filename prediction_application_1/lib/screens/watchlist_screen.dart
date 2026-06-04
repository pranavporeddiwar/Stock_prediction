import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'stock_prediction_screen.dart';

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

  // Optimized: Pre-calculate the A-Z list to prevent lag during search
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
    // 1. Pre-map symbols once to avoid repeated O(n) work
    _preCalculatedSuggestions = _allMarketStocks
        .map((s) => {'symbol': s, 'price': 0.0, 'signal': 'VIEW'})
        .toList();
    
    _loadWatchlist();
    
    // 2. Setup Background Sync (10s)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isSearching && mounted) _loadWatchlist(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() {
      isSearching = query.isNotEmpty || FocusScope.of(context).hasFocus;
      if (query.isEmpty) {
        filteredStocks = _preCalculatedSuggestions;
      } else {
        // High-speed filtering using pre-mapped data
        final lowercaseQuery = query.toLowerCase();
        filteredStocks = _preCalculatedSuggestions
            .where((s) => s['symbol'].toLowerCase().contains(lowercaseQuery))
            .toList();
      }
    });
  }

  Future<void> _loadWatchlist({bool isSilent = false}) async {
    if (!mounted || isSearching) return;
    if (!isSilent) setState(() => isLoading = true);
    
    try {
      final data = await ApiService().getWatchlistOverview();
      if (mounted) {
        setState(() {
          stocks = data;
          filteredStocks = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Watchlist Sync Error: $e");
      if (mounted && !isSilent) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          isSearching ? "MARKET DISCOVERY" : "AI MARKET MONITOR",
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 2
          ),
        ),
        leading: isSearching 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFA3), size: 20),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _searchController.clear();
                setState(() {
                  isSearching = false;
                  filteredStocks = stocks;
                });
              },
            )
          : null,
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: isLoading && stocks.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3), strokeWidth: 2))
                : _buildWatchlist(),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlist() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1.0,
      child: ListView.builder(
        // VIVO PERFORMANCE TWEAKS
        physics: const BouncingScrollPhysics(),
        cacheExtent: 1000, 
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemCount: filteredStocks.length,
        itemBuilder: (context, i) => _buildStockCard(filteredStocks[i]),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus && !isSearching) {
            setState(() {
              isSearching = true;
              _onSearchChanged(_searchController.text);
            });
          }
        },
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search A-Z Symbols...",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FFA3), size: 18),
            filled: true,
            fillColor: const Color(0xFF111111), // Solid hex for faster rendering
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18), 
              borderSide: BorderSide.none
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard(dynamic s) {
    final String symbol = s['symbol']?.toString() ?? "N/A";
    final double price = (s['price'] ?? 0.0).toDouble();
    final String signal = s['signal']?.toString() ?? "HOLD";
    final bool isBuy = signal == "BUY";
    final bool isSuggestion = signal == "VIEW";

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StockPredictionScreen(symbol: symbol)),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            // Removed Opacity/Transparency to fix Gralloc4 errors
            color: isSuggestion ? Colors.black : const Color(0xFF0D0D0D), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isBuy ? const Color(0xFF00FFA3).withOpacity(0.15) : const Color(0xFF1A1A1A),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(symbol, 
                    style: TextStyle(
                      color: isSuggestion ? Colors.white54 : Colors.white, 
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  if (!isSuggestion) ...[
                    const SizedBox(height: 4),
                    Text("₹${price.toStringAsFixed(1)}", 
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]
                ]
              ),
              if (isSuggestion)
                const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 12)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBuy ? const Color(0x1A00FFA3) : const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    signal, 
                    style: TextStyle(
                      color: isBuy ? const Color(0xFF00FFA3) : Colors.white60, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 10
                    )
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}