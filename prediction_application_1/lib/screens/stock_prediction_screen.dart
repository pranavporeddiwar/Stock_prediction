import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/api_service.dart';
import '../services/live_stream_service.dart';
import '../models/stock_data.dart';
import 'investment_helper_page.dart';
import '../utils/app_state.dart'; 
import '../widgets/bottom_nav_bar.dart';
import '../widgets/global_chat_bot.dart';
import '../widgets/stock_chart.dart';

// --- DATA MODELS ---
class ChartNode {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final bool isPredicted;
  final String pattern;
  final String risk;

  ChartNode({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.isPredicted = false,
    this.pattern = "Standard",
    this.risk = "Low risk",
  });
}

class StockPredictionScreen extends StatefulWidget {
  final String symbol;
  const StockPredictionScreen({super.key, required this.symbol});

  @override
  State<StockPredictionScreen> createState() => _StockPredictionScreenState();
}

class _StockPredictionScreenState extends State<StockPredictionScreen> {
  StockData? data;
  bool isLoading = true;
  String? _errorMessage;
  
  final LiveStreamService _streamService = LiveStreamService();
  StreamSubscription? _streamSubscription;
  late TrackballBehavior _trackballBehavior;
  Timer? _autoRefreshTimer; // 1-minute auto-refresh for latest candle forecast

  // Theme Colors
  final Color bgDark = const Color(0xFF0F1219);
  final Color cardDark = const Color(0xFF161A23);
  final Color neonGreen = const Color(0xFF22D372);
  final Color neonRed = const Color(0xFFF34141);

  @override
  void initState() {
    super.initState();
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipSettings: const InteractiveTooltip(
        enable: true,
        color: Color(0xFF161A23),
        textStyle: TextStyle(color: Colors.white, fontSize: 11),
      ),
      lineType: TrackballLineType.vertical,
      lineColor: Colors.white24,
    );
    _startLiveStream();
    // Start 1-minute auto-refresh for latest candle forecast
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshForecast();
    });
  }

  StockData _normalizeStockData(StockData data) {
    if (data.history.isEmpty || data.predictedPath.isEmpty) return data;
    
    double lastRealClose = data.currentPrice > 0 ? data.currentPrice : data.history.last.close;
    double rawBase = data.predictedPath.first.close;
    double offset = lastRealClose - rawBase;
    
    // Limit history to 25 candles for a zoomed-in, beautiful view
    List<CandleModel> trimmedHistory = data.history.length > 25 
        ? data.history.sublist(data.history.length - 25) 
        : data.history;
    
    // Limit predictions to 6-8 candles
    List<CandleModel> trimmedFuture = data.predictedPath.length > 8 
        ? data.predictedPath.sublist(0, 8) 
        : data.predictedPath;
        
    List<CandleModel> newPath = trimmedFuture.map((p) => CandleModel(
      time: p.time,
      open: p.open + offset,
      high: p.high + offset,
      low: p.low + offset,
      close: p.close + offset,
      volume: p.volume,
      pattern: p.pattern,
      risk: p.risk,
    )).toList();
    
    // Derive target & stop loss from the NORMALIZED predicted candles
    // so they stay within the visible chart range
    double maxPredictedClose = newPath.fold(newPath.first.close, (m, c) => c.close > m ? c.close : m);
    double minPredictedLow = newPath.fold(newPath.first.low, (m, c) => c.low < m ? c.low : m);
    double newTarget = maxPredictedClose;
    double newStopLoss = minPredictedLow;
    
    return StockData(
      symbol: data.symbol,
      currentPrice: data.currentPrice,
      history: trimmedHistory,
      predictedPath: newPath,
      sentiment: data.sentiment,
      suitability: data.suitability,
      action: data.action,
      reasoning: data.reasoning,
      stopLoss: newStopLoss,
      targetPrice: newTarget,
      buyTime: data.buyTime,
      sellTime: data.sellTime,
      tradingStyle: data.tradingStyle,
      styleReason: data.styleReason,
      riskLevel: data.riskLevel,
      rsi: data.rsi,
      trendLogic: data.trendLogic,
    );
  }

  void _refreshForecast() async {
    if (!mounted) return;
    try {
      final freshData = await ApiService().fetchPrediction(widget.symbol, "intraday");
      if (mounted && freshData.history.isNotEmpty) {
        setState(() => data = _normalizeStockData(freshData));
      }
    } catch (_) {
      // Silent refresh — don't disrupt the user
    }
  }

  void _startLiveStream() async {
    if (!mounted) return;
    setState(() { isLoading = true; _errorMessage = null; });
    
    try {
      final initialData = await ApiService().fetchPrediction(widget.symbol, "intraday");
      if (!mounted) return;
      setState(() { data = _normalizeStockData(initialData); isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      // Extract the meaningful part of the error message
      String errMsg = e.toString().replaceAll('Exception: ', '');
      setState(() { isLoading = false; _errorMessage = errMsg; });
      return; 
    }

    _streamSubscription = _streamService.connectToLiveStream(widget.symbol).listen(
      (liveData) {
        if (!mounted || data == null) return;
        setState(() {
          // ⚡ ONLY update the live price, RSI, and trend from the stream.
          // Preserve the original rich history & predicted path from the
          // initial API call so the chart doesn't squeeze/collapse.
          data = StockData(
            symbol: data!.symbol,
            currentPrice: liveData.currentPrice,
            history: data!.history,
            predictedPath: data!.predictedPath,
            sentiment: data!.sentiment,
            suitability: data!.suitability,
            action: data!.action,
            reasoning: data!.reasoning, 
            stopLoss: data!.stopLoss,
            targetPrice: data!.targetPrice,
            buyTime: data!.buyTime,
            sellTime: data!.sellTime,
            tradingStyle: data!.tradingStyle,
            styleReason: data!.styleReason,
            riskLevel: data!.riskLevel,
            rsi: liveData.rsi,
            trendLogic: liveData.trendLogic,
          );
        });
      },
      onError: (e) {
        debugPrint("⚠️ Live stream error: $e");
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamService.disconnect();
    super.dispose();
  }

  List<ChartNode> _buildForecastNodes(DateTime cutoffTime, double lastClose) {
    List<ChartNode> nodes = [];
    Random rand = Random(42); 
    
    for (int i = 0; i < data!.predictedPath.length; i++) {
      DateTime time = cutoffTime.add(Duration(minutes: 15 * (i + 1)));
      var c = data!.predictedPath[i];
      
      double pClose = c.close;
      double pOpen = i == 0 ? lastClose : data!.predictedPath[i - 1].close;
      double variance = pClose * 0.002; 
      double pHigh = max(pOpen, pClose) + (rand.nextDouble() * variance);
      double pLow = min(pOpen, pClose) - (rand.nextDouble() * variance);

      nodes.add(ChartNode(
        time: time, open: pOpen, high: pHigh, low: pLow, close: pClose, 
        isPredicted: true, pattern: c.pattern ?? "Standard", risk: c.risk ?? "Low risk"
      ));
    }
    return nodes;
  }

  // ==========================================
  // ⚠️ ERROR STATE WITH MARKET-CLOSED DETECTION & RETRY
  // ==========================================
  bool _isMarketClosed() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)); // IST
    final weekday = now.weekday; // 1=Mon ... 7=Sun
    if (weekday == 6 || weekday == 7) return true; // Weekend
    final minutes = now.hour * 60 + now.minute;
    // NSE trading hours: 9:15 AM to 3:30 PM IST
    return minutes < 555 || minutes > 930; // 555 = 9:15, 930 = 15:30
  }

  Widget _buildErrorScreen() {
    final bool marketClosed = false; // _isMarketClosed(); bypassed for testing
    
    // Pick the right icon, title, and message based on context
    final IconData icon;
    final String title;
    final String subtitle;
    final Color accentColor;

    if (marketClosed) {
      icon = Icons.nightlight_round;
      title = "MARKET CLOSED";
      subtitle = "NSE trading hours: Mon–Fri, 9:15 AM – 3:30 PM IST.\nData will refresh when markets reopen.";
      accentColor = const Color(0xFFFFC107);
    } else if (_errorMessage != null && _errorMessage!.contains("503")) {
      icon = Icons.cloud_off_rounded;
      title = "BROKER OFFLINE";
      subtitle = "The data broker session has expired.\nThe server is attempting to reconnect.";
      accentColor = Colors.orangeAccent;
    } else if (_errorMessage != null && _errorMessage!.contains("not found")) {
      icon = Icons.search_off_rounded;
      title = "SYMBOL NOT FOUND";
      subtitle = "'${widget.symbol}' was not found in NSE listings.\nPlease check the ticker symbol.";
      accentColor = Colors.redAccent;
    } else {
      icon = Icons.wifi_off_rounded;
      title = "DATA UNAVAILABLE";
      subtitle = _errorMessage ?? "Unable to fetch market data.\nPlease check your connection and retry.";
      accentColor = Colors.redAccent;
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white54),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing icon container
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.08),
                  border: Border.all(color: accentColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 36),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              // Retry button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _startLiveStream,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text("RETRY CONNECTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor.withOpacity(0.12),
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Go back button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("← BACK TO WATCHLIST", style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(backgroundColor: bgDark, body: Center(child: CircularProgressIndicator(color: neonGreen)));
    }
    if (data == null || data!.history.isEmpty) {
      return _buildErrorScreen();
    }

    // ⚡ PRE-CALCULATE ALL DATA NODES ONCE FOR PERFECT SYNCHRONIZATION
    List<ChartNode> historyNodes = [];
    // Use a fixed market-session anchor: today at 09:15 IST
    final now = DateTime.now();
    // Anchor the history so the last candle ends at ~current time
    final DateTime lastCandleTime = DateTime(now.year, now.month, now.day, now.hour,
        (now.minute ~/ 15) * 15); // Round down to nearest 15 min

    for (int i = 0; i < data!.history.length; i++) {
      // Spread candles backwards from lastCandleTime
      DateTime time = lastCandleTime.subtract(Duration(minutes: 15 * (data!.history.length - 1 - i)));
      var c = data!.history[i];
      // Use currentPrice as fallback but ensure we have at least a tiny OHLC spread
      double close = c.close > 0 ? c.close : data!.currentPrice;
      double open = c.open > 0 ? c.open : close;
      double high = c.high > 0 ? c.high : (close > open ? close : open) * 1.001;
      double low = c.low > 0 ? c.low : (close < open ? close : open) * 0.999;
      historyNodes.add(ChartNode(time: time, open: open, high: high, low: low, close: close));
    }

    DateTime cutoffTime = historyNodes.isNotEmpty ? historyNodes.last.time : lastCandleTime;
    double lastClose = historyNodes.isNotEmpty ? historyNodes.last.close : data!.currentPrice;
    
    List<ChartNode> forecastNodes = _buildForecastNodes(cutoffTime, lastClose);

    // ⚡ MATHEMATICAL SEARCH: Find Exact Execution Times based on highest and lowest future prices
    ChartNode? bestBuyNode;
    ChartNode? bestSellNode;
    if (forecastNodes.isNotEmpty) {
      bestBuyNode = forecastNodes.reduce((curr, next) => curr.close < next.close ? curr : next);
      bestSellNode = forecastNodes.reduce((curr, next) => curr.close > next.close ? curr : next);
    }

    return Scaffold(
      backgroundColor: bgDark,
      extendBody: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.symbol.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Text("NSE • Intraday • AI Forecast", style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white54, size: 20), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white54, size: 20), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderPrice(),
            _buildChartSection(historyNodes, forecastNodes, cutoffTime, bestBuyNode, bestSellNode),
            _buildBuySellSignalCard(),
            _buildTradingStyleCard(),
            _buildImmediatePredictionCard(forecastNodes),
            _buildConfidenceAndActionCards(bestBuyNode, bestSellNode),
            _buildUpcomingForecastList(forecastNodes, bestBuyNode, bestSellNode),
            _buildAiBotLink(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7B2CBF),
        onPressed: () => GlobalChatBot.show(context),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderPrice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₹${data!.currentPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text("+0.20 (0.11%)", style: TextStyle(color: neonGreen, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.auto_awesome, color: neonGreen, size: 14),
              const SizedBox(width: 6),
              const Text("AI confidence on next 6 candles • ", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("${(data!.sentiment * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: ['1D', '1W', '1M', '3M', '1Y', '5Y'].map((t) => Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: t == '1D' ? neonGreen.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t == '1D' ? neonGreen : Colors.white12),
              ),
              child: Text(t, style: TextStyle(color: t == '1D' ? neonGreen : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildChartSection(List<ChartNode> historyNodes, List<ChartNode> forecastNodes, DateTime cutoffTime, ChartNode? bestBuy, ChartNode? bestSell) {
    return Column(
      children: [
        SizedBox(
          height: 360,
          child: CustomPaint(
            painter: CandleChartPainter(
              candles: data!.history,
              futureData: data!.predictedPath,
              aiTargetPrice: data!.targetPrice,
              suggestedBuyPrice: bestBuy?.close,
              suggestedSellPrice: bestSell?.close,
              stopLoss: data!.stopLoss,
              bullColor: neonGreen,
              bearColor: neonRed,
              gridColor: const Color(0xFF1E222D),
              textColor: Colors.white54,
              priceTagColor: neonGreen,
              aiLineColor: const Color(0xFF2962FF),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(neonGreen, "Bullish"),
            const SizedBox(width: 15),
            _buildLegendDot(neonRed, "Bearish"),
            const SizedBox(width: 15),
            _buildLegendDot(Colors.transparent, "Predicted", borderColor: const Color(0xFF2962FF)),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label, {Color? borderColor}) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildImmediatePredictionCard(List<ChartNode> forecastNodes) {
    if (forecastNodes.isEmpty) return const SizedBox.shrink();
    ChartNode firstFuture = forecastNodes.first;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("AI PREDICTION • ${DateFormat('HH:mm').format(firstFuture.time)}", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: neonGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: neonGreen.withOpacity(0.3))),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: neonGreen, size: 12),
                    const SizedBox(width: 4),
                    Text(firstFuture.risk, style: TextStyle(color: neonGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(firstFuture.pattern, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: neonGreen, borderRadius: BorderRadius.circular(10)),
                child: const Text("BUY", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOHLCValue("Open", firstFuture.open),
              _buildOHLCValue("High", firstFuture.high),
              _buildOHLCValue("Low", firstFuture.low),
              _buildOHLCValue("Close", firstFuture.close),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildOHLCValue(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text("₹${value.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConfidenceAndActionCards(ChartNode? bestBuy, ChartNode? bestSell) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Model confidence", style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text("${(data!.sentiment * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: data!.sentiment,
              backgroundColor: Colors.white10, color: neonGreen, minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // ⚡ BEST BUY CARD (Dynamically Synced to AI Path)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: neonGreen.withOpacity(0.05),
                    border: Border.all(color: neonGreen.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: neonGreen, size: 16),
                          const SizedBox(width: 5),
                          Text("BEST BUY", style: TextStyle(color: neonGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("₹${bestBuy?.close.toStringAsFixed(2) ?? data!.currentPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Today • ${bestBuy != null ? DateFormat('hh:mm a').format(bestBuy.time) : '--:--'}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(bestBuy?.pattern ?? "Analyzing...", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // ⚡ BEST SELL CARD (Dynamically Synced to AI Path)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: neonRed.withOpacity(0.05),
                    border: Border.all(color: neonRed.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_down, color: neonRed, size: 16),
                          const SizedBox(width: 5),
                          Text("BEST SELL", style: TextStyle(color: neonRed, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("₹${bestSell?.close.toStringAsFixed(2) ?? data!.targetPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Today • ${bestSell != null ? DateFormat('hh:mm a').format(bestSell.time) : '--:--'}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(bestSell?.pattern ?? "Analyzing...", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildUpcomingForecastList(List<ChartNode> forecastNodes, ChartNode? bestBuy, ChartNode? bestSell) {
    if (forecastNodes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Upcoming candle forecast", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentHelperPage(data: data!))), 
                child: Text("View all >", style: TextStyle(color: neonGreen, fontSize: 12))
              )
            ],
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: forecastNodes.length > 5 ? 5 : forecastNodes.length,
            itemBuilder: (context, index) {
              ChartNode node = forecastNodes[index];
              Color riskColor = node.risk.contains("Low") ? neonGreen : (node.risk.contains("Med") ? Colors.orange : neonRed);
              
              // ⚡ Dynamic tagging based on exact time sync
              String actLabel = "";
              if (node.time == bestBuy?.time) actLabel = "BUY";
              if (node.time == bestSell?.time) actLabel = "SELL";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: node.time == bestBuy?.time ? Border.all(color: neonGreen.withOpacity(0.5)) : Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                      child: const Icon(Icons.access_time, color: Colors.white54, size: 16),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(DateFormat('HH:mm').format(node.time), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              if (actLabel.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: actLabel == "BUY" ? neonGreen : neonRed, borderRadius: BorderRadius.circular(10)),
                                  child: Text(actLabel, style: TextStyle(color: actLabel == "BUY" ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                )
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("${node.pattern} • close ≈ ₹${node.close.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: riskColor.withOpacity(0.1), border: Border.all(color: riskColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(node.risk.contains("Low") ? Icons.shield_outlined : Icons.warning_amber_rounded, color: riskColor, size: 12),
                          const SizedBox(width: 4),
                          Text(node.risk, style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }

  // ==========================================
  // 📊 BUY/SELL SIGNAL CARD WITH TIMESTAMPS
  // ==========================================
  Widget _buildBuySellSignalCard() {
    if (data == null) return const SizedBox.shrink();
    
    final action = data!.action;
    final isBuy = action == "BUY";
    final actionColor = isBuy ? neonGreen : (action == "SELL" ? neonRed : Colors.amber);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: actionColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: actionColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: actionColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(action, style: TextStyle(color: isBuy ? Colors.black : Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              const SizedBox(width: 12),
              Text("SIGNAL", style: TextStyle(color: actionColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("Risk: ${data!.riskLevel}", style: TextStyle(color: data!.riskLevel == "Low" ? neonGreen : (data!.riskLevel == "High" ? neonRed : Colors.amber), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buy & Sell time row
          Row(
            children: [
              Expanded(
                child: _buildTimeBlock("BUY AT", data!.buyTime, neonGreen, Icons.arrow_downward_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeBlock("SELL AT", data!.sellTime, neonRed, Icons.arrow_upward_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Target & Stop Loss row
          Row(
            children: [
              Expanded(
                child: _buildPriceChip("TARGET", data!.targetPrice, neonGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceChip("STOP LOSS", data!.stopLoss, neonRed),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // AI Reasoning
          Text(data!.reasoning, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(String label, String time, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 6),
          Text(time.isNotEmpty ? time : "Calculating...", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPriceChip(String label, double price, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          Text("₹${price.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================
  // 🎯 TRADING STYLE RECOMMENDATION CARD
  // ==========================================
  Widget _buildTradingStyleCard() {
    if (data == null) return const SizedBox.shrink();
    
    final style = data!.tradingStyle;
    final IconData styleIcon;
    final Color styleColor;
    
    switch (style) {
      case "Scalping":
        styleIcon = Icons.flash_on_rounded;
        styleColor = Colors.orangeAccent;
        break;
      case "Intraday":
        styleIcon = Icons.today_rounded;
        styleColor = const Color(0xFF00BCD4);
        break;
      case "Swing":
        styleIcon = Icons.trending_up_rounded;
        styleColor = const Color(0xFF9D4EDD);
        break;
      case "Positional":
        styleIcon = Icons.calendar_month_rounded;
        styleColor = const Color(0xFF4CAF50);
        break;
      default:
        styleIcon = Icons.auto_graph;
        styleColor = Colors.white54;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: styleColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: styleColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: styleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(styleIcon, color: styleColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("RECOMMENDED: ", style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1)),
                    Text(style.toUpperCase(), style: TextStyle(color: styleColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(data!.styleReason, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🤖 AI BOT LINK AT BOTTOM
  // ==========================================
  Widget _buildAiBotLink() {
    return GestureDetector(
      onTap: () => GlobalChatBot.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF7B2CBF).withOpacity(0.15), const Color(0xFF9D4EDD).withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF9D4EDD).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF9D4EDD), size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Want deeper insights?", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text("Ask our AI bot for detailed prediction analysis", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9D4EDD), size: 16),
          ],
        ),
      ),
    );
  }
}