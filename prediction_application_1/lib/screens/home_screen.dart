import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'stock_prediction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> momentum = {};
  List<Map<String, dynamic>> news = [];
  List<Map<String, dynamic>> watchlistStocks = [];
  bool isLoadingMomentum = true;
  bool isLoadingNews = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _loadAllData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadAllData() async {
    _loadMomentum();
    _loadNews();
    _loadWatchlist();
  }

  void _loadMomentum() async {
    try {
      final data = await ApiService().getMarketMomentum();
      if (mounted) setState(() { momentum = data; isLoadingMomentum = false; });
    } catch (_) {
      if (mounted) setState(() => isLoadingMomentum = false);
    }
  }

  void _loadNews() async {
    try {
      final data = await ApiService().getMarketNews();
      if (mounted) setState(() { news = data; isLoadingNews = false; });
    } catch (_) {
      if (mounted) setState(() => isLoadingNews = false);
    }
  }

  void _loadWatchlist() async {
    try {
      final data = await ApiService().getWatchlistOverview();
      if (mounted) setState(() => watchlistStocks = data);
    } catch (_) {
      // Silent — don't crash the home screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.black,
            floating: true,
            title: const Text("NEUROTICK TERMINAL", style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
          ),
          
          // 1. Market Momentum — Live Data
          SliverToBoxAdapter(child: _buildMomentumCard()),

          // 2. Stock Recommendations by Trading Style
          SliverToBoxAdapter(child: _buildStockRecommendations()),

          // 3. Real-Time News Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 20, top: 30, bottom: 10),
              child: Text("REAL-TIME INTELLIGENCE", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
            ),
          ),

          // 4. News Cards — Live from yfinance
          isLoadingNews
            ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF9D4EDD)))))
            : news.isEmpty
              ? const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Text("No news available right now", style: TextStyle(color: Colors.white38), textAlign: TextAlign.center)))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildNewsCard(news[index]),
                    childCount: news.length,
                  ),
                ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ==========================================
  // 📊 MARKET MOMENTUM CARD — LIVE DATA
  // ==========================================
  Widget _buildMomentumCard() {
    final state = momentum['state'] ?? 'LOADING';
    final momentumLevel = momentum['momentum'] ?? 'LOADING';
    final summary = momentum['summary'] ?? 'Fetching market data...';
    final strategy = momentum['strategy'] ?? 'Loading...';
    final niftyChange = (momentum['nifty_change'] ?? 0.0).toDouble();
    
    final bool isBullish = state == 'BULLISH';
    final Color stateColor = isBullish ? const Color(0xFF00FFA3) : (state == 'BEARISH' ? Colors.redAccent : Colors.amber);
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stateColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: stateColor.withOpacity(0.1), blurRadius: 20, spreadRadius: -5)],
      ),
      child: isLoadingMomentum
        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF9D4EDD))))
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("OVERALL MARKET STATE", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(state, style: TextStyle(color: stateColor, fontSize: 28, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: stateColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(momentumLevel, style: TextStyle(color: stateColor, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 14),
            // Nifty/Sensex summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
              child: Text(summary, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ),
            const SizedBox(height: 14),
            const Text("ALGORITHMIC SUGGESTION", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.insights, color: const Color(0xFF9D4EDD), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(strategy, style: const TextStyle(color: Colors.white, fontSize: 13))),
                ],
              ),
            )
          ],
        ),
    );
  }

  // ==========================================
  // 🎯 STOCK RECOMMENDATIONS BY TRADING STYLE
  // ==========================================
  Widget _buildStockRecommendations() {
    // Group stocks by trading style from watchlist data
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var stock in watchlistStocks) {
      final style = stock['trading_style']?.toString() ?? stock['signal']?.toString() ?? 'VIEW';
      grouped.putIfAbsent(style, () => []);
      grouped[style]!.add(stock);
    }

    // Fallback categories if watchlist doesn't have trading_style
    final tabs = grouped.keys.isNotEmpty ? grouped.keys.toList() : ['TODAY', 'SHORT-TERM', 'LONG-TERM'];
    
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            indicatorColor: const Color(0xFF00FFA3),
            labelColor: const Color(0xFF00FFA3),
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.transparent,
            isScrollable: tabs.length > 3,
            tabs: tabs.map((t) => Tab(text: t.toUpperCase())).toList(),
          ),
          SizedBox(
            height: 150,
            child: TabBarView(
              children: tabs.map((style) {
                final stocks = grouped[style] ?? [];
                if (stocks.isEmpty) {
                  return const Center(child: Text("No recommendations", style: TextStyle(color: Colors.white38, fontSize: 12)));
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: stocks.length,
                  itemBuilder: (context, index) {
                    final stock = stocks[index];
                    return _buildRecommendationTile(stock, style);
                  },
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecommendationTile(Map<String, dynamic> stock, String style) {
    final symbol = stock['symbol']?.toString() ?? 'UNKNOWN';
    final price = (stock['price'] ?? stock['current_price'] ?? 0).toDouble();
    final changePct = (stock['change_pct'] ?? 0).toDouble();
    final isPositive = changePct >= 0;
    
    return GestureDetector(
      onTap: () {
        // Show bottom sheet with trading style reasoning, then navigate
        _showStyleReasoning(context, stock, style);
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
            if (price > 0)
              Text("₹${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(
              "${isPositive ? '+' : ''}${changePct.toStringAsFixed(2)}%",
              style: TextStyle(color: isPositive ? const Color(0xFF00FFA3) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(style.toUpperCase(), style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showStyleReasoning(BuildContext context, Map<String, dynamic> stock, String style) {
    final symbol = stock['symbol']?.toString() ?? 'UNKNOWN';
    final reason = stock['style_reason']?.toString() ?? 'This stock is recommended for $style trading based on current market analysis.';
    final rsi = (stock['rsi'] ?? 50).toDouble();
    final volatility = (stock['volatility'] ?? 0).toDouble();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text("WHY $style FOR $symbol?", style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 14),
            Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricChip("RSI", rsi.toStringAsFixed(0), rsi > 70 ? Colors.redAccent : (rsi < 30 ? const Color(0xFF00FFA3) : Colors.amber)),
                const SizedBox(width: 10),
                _buildMetricChip("Volatility", "${volatility.toStringAsFixed(1)}%", volatility > 2 ? Colors.redAccent : const Color(0xFF00FFA3)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StockPredictionScreen(symbol: symbol)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text("VIEW $symbol PREDICTION →", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================
  // 📰 REAL NEWS CARD
  // ==========================================
  Widget _buildNewsCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final publisher = item['publisher']?.toString() ?? 'Market Wire';
    final timeAgo = item['time_ago']?.toString() ?? '';
    final thumbnail = item['thumbnail']?.toString() ?? '';
    final relatedSymbol = item['related_symbol']?.toString() ?? '';
    
    return GestureDetector(
      onTap: relatedSymbol.isNotEmpty ? () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StockPredictionScreen(symbol: relatedSymbol)));
      } : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
                image: thumbnail.isNotEmpty ? DecorationImage(
                  image: NetworkImage(thumbnail),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                ) : null,
              ),
              child: thumbnail.isEmpty ? const Icon(Icons.newspaper, color: Colors.white24, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text("$timeAgo • $publisher", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      if (relatedSymbol.isNotEmpty) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF9D4EDD).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(relatedSymbol, style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}