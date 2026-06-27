import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/api_service.dart';
import '../services/live_stream_service.dart';
import '../models/stock_data.dart';
import 'investment_helper_page.dart';
import '../utils/app_state.dart'; 
import '../widgets/bottom_nav_bar.dart';
import '../widgets/global_chat_bot.dart'; 

class StockPredictionScreen extends StatefulWidget {
  final String symbol;
  const StockPredictionScreen({super.key, required this.symbol});

  @override
  State<StockPredictionScreen> createState() => _StockPredictionScreenState();
}

class _StockPredictionScreenState extends State<StockPredictionScreen> {
  StockData? data;
  bool isLoading = true;
  
  final LiveStreamService _streamService = LiveStreamService();
  StreamSubscription? _streamSubscription;
  
  late TrackballBehavior _trackballBehavior;
  late ZoomPanBehavior _zoomPanBehavior; 

  @override
  void initState() {
    super.initState();
    
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipSettings: const InteractiveTooltip(
        enable: true,
        color: Color(0xFF1A1A1A),
        borderColor: Color(0xFF00FFA3),
        borderWidth: 1,
        textStyle: TextStyle(color: Colors.white, fontSize: 10),
      ),
      lineType: TrackballLineType.vertical,
      lineColor: Colors.white24,
      lineWidth: 1,
      markerSettings: const TrackballMarkerSettings(
        markerVisibility: TrackballVisibilityMode.visible,
        height: 6, width: 6,
        color: Color(0xFF00FFA3),
      ),
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.x, 
    );

    _startLiveStream();
  }

  void _startLiveStream() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final initialData = await ApiService().fetchPrediction(widget.symbol, "intraday");
      if (mounted) {
        setState(() {
          data = initialData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Neural Sync Error: $e")),
        );
      }
      return; 
    }

    // 🔒 Safely manage subscription node memory
    _streamSubscription = _streamService.connectToLiveStream(widget.symbol).listen((liveData) {
      if (mounted && data != null) {
        setState(() {
          data = StockData(
            symbol: data!.symbol,
            currentPrice: liveData.currentPrice,
            history: liveData.history,
            predictedPath: liveData.predictedPath,
            sentiment: data!.sentiment,
            suitability: data!.suitability,
            action: data!.action,
            reasoning: data!.reasoning, 
            stopLoss: data!.stopLoss,
            targetPrice: data!.targetPrice,
            rsi: liveData.rsi,
            trendLogic: liveData.trendLogic,
          );
        });
        
        // ⚡ Continuous syncing to the LLM agent's short-term memory block
        final String currentDateTime = DateTime.now().toString().split('.')[0];
        currentBotContext.value = 
          "STOCK SYMBOL: ${widget.symbol.toUpperCase()}\n"
          "CURRENT TIMESTAMP: $currentDateTime\n"
          "LIVE TICK PRICE: ₹${liveData.currentPrice}\n"
          "CURRENT RSI VALUE: ${liveData.rsi.toStringAsFixed(2)}\n"
          "INITIAL AI SIGNAL: ${data!.action}\n"
          "LSTM FUTURE PATH FORECAST (Next 25 Steps of 15-min candles):\n"
          "${liveData.predictedPath.map((candle) => 'Close: ₹${candle.close}').toList()}";
      }
    }, onError: (error) {
      debugPrint("WebSocket Stream Interrupted: $error");
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _streamService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = data != null && data!.history.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true, 
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.symbol.toUpperCase()} NEURAL TERMINAL",
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 11, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.5
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3), strokeWidth: 2))
          : !hasData 
              ? _buildNoDataUI()
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100), 
                  child: Column(
                    children: [
                      _buildAdvancedTradingChart(),
                      _buildTradeExecutionCard(),
                      _buildTechnicalInsights(),
                      _buildNeuralReasoning(),
                    ],
                  ),
                ),
      
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9D4EDD).withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF7B2CBF),
          shape: const CircleBorder(),
          onPressed: () => GlobalChatBot.show(context),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0, 
        onTap: (index) => Navigator.pop(context),
      ),
    );
  }

  Widget _buildAdvancedTradingChart() {
    final int historyCount = data!.history.length;
    final double initialVisibleMin = historyCount > 60 ? (historyCount - 60).toDouble() : 0.0;
    final double initialVisibleMax = (historyCount + 10).toDouble(); 

    final bool showBuy = data!.action == "BUY";
    final bool showSell = data!.action == "SELL";

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.42, 
      child: SfCartesianChart(
        margin: const EdgeInsets.fromLTRB(5, 15, 5, 5),
        plotAreaBorderWidth: 0,
        zoomPanBehavior: _zoomPanBehavior,
        trackballBehavior: _trackballBehavior,
        primaryXAxis: NumericAxis(
          isVisible: false, 
          initialVisibleMinimum: initialVisibleMin,
          initialVisibleMaximum: initialVisibleMax,
        ),
        primaryYAxis: const NumericAxis(
          opposedPosition: true, 
          anchorRangeToVisiblePoints: true, 
          labelPosition: ChartDataLabelPosition.outside,
          labelStyle: TextStyle(color: Colors.white60, fontSize: 9),
          axisLine: AxisLine(width: 0),
          majorGridLines: MajorGridLines(color: Colors.white10, width: 0.5), 
        ),
        series: <CartesianSeries>[
          // 📊 HISTORICAL LIVE DATA 
          CandleSeries<CandleModel, int>(
            dataSource: data!.history,
            xValueMapper: (_, i) => i,
            lowValueMapper: (c, _) => c.low,
            highValueMapper: (c, _) => c.high,
            openValueMapper: (c, _) => c.open,
            closeValueMapper: (c, _) => c.close,
            bullColor: const Color(0xFF00FFA3),
            bearColor: const Color(0xFFFF3E3E),
            enableSolidCandles: true,
          ),
          // 🔮 AI FORECAST PATH 
          CandleSeries<CandleModel, int>(
            dataSource: data!.predictedPath,
            xValueMapper: (_, i) => historyCount + i,
            lowValueMapper: (c, _) => c.low,
            highValueMapper: (c, _) => c.high,
            openValueMapper: (c, _) => c.open,
            closeValueMapper: (c, _) => c.close,
            opacity: 0.5,
            dashArray: const <double>[3, 3],
            bullColor: const Color(0xFF00FFA3),
            bearColor: const Color(0xFFFF3E3E),
            enableSolidCandles: false,
          ),
          // ⚡ EXPLICIT BUY INDICATOR (Overlaid on last historical tick)
          if (showBuy)
            ScatterSeries<CandleModel, int>(
              dataSource: [data!.history.last],
              xValueMapper: (_, __) => historyCount - 1,
              yValueMapper: (c, _) => c.low * 0.998, // Offset just below candle
              markerSettings: const MarkerSettings(
                shape: DataMarkerType.verticalLine, // Forms sharp custom arrow head
                color: Color(0xFF00FFA3),
                height: 14, width: 14,
              ),
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: Color(0xFF00FFA3), fontSize: 9, fontWeight: FontWeight.bold),
                labelAlignment: ChartDataLabelAlignment.bottom,
              ),
            ),
          // ⚡ EXPLICIT SELL INDICATOR (Overlaid on last historical tick)
          if (showSell)
            ScatterSeries<CandleModel, int>(
              dataSource: [data!.history.last],
              xValueMapper: (_, __) => historyCount - 1,
              yValueMapper: (c, _) => c.high * 1.002, // Offset just above candle
              markerSettings: const MarkerSettings(
                shape: DataMarkerType.invertedTriangle,
                color: Color(0xFFFF3E3E),
                height: 12, width: 12,
              ),
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: Color(0xFFFF3E3E), fontSize: 9, fontWeight: FontWeight.bold),
                labelAlignment: ChartDataLabelAlignment.top,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeExecutionCard() {
    final bool isBuy = data!.action == "BUY";
    final Color actionColor = isBuy ? const Color(0xFF00FFA3) : (data!.action == "SELL" ? Colors.redAccent : Colors.orangeAccent);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isBuy ? const Color(0xFF001F13) : (data!.action == "SELL" ? const Color(0xFF240000) : const Color(0xFF141414)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: actionColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("NEURAL SIGNAL", style: TextStyle(color: actionColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(data!.action, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text("TARGET: ₹${data!.targetPrice.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("STOP: ₹${data!.stopLoss.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _buildTechnicalInsights() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("HYBRID DATA FUSION", 
            style: TextStyle(color: Color(0xFF00FFA3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _insightRow("Relative Strength (RSI)", data!.rsi.toStringAsFixed(1), _getRsiStatus(data!.rsi)),
          const Divider(color: Colors.white12, height: 20),
          _insightRow("Stock Sentiment", "${(data!.sentiment * 100).toStringAsFixed(0)}%", data!.suitability),
        ],
      ),
    );
  }

  Widget _buildNeuralReasoning() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("GROQ AI THESIS", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(data!.reasoning, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFA3),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentHelperPage(data: data!))),
              child: const Text("PROCEED TO CAPITAL ALLOCATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            ),
          )
        ],
      ),
    );
  }

  Widget _insightRow(String label, String value, String status) {
    final bool isPositive = status.contains("BULLISH") || status == "OVERSOLD" || status.contains("HIGH");
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Row(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(status, style: TextStyle(
              color: isPositive ? const Color(0xFF00FFA3) : Colors.orangeAccent,
              fontSize: 10, fontWeight: FontWeight.bold
            )),
          ],
        ),
      ],
    );
  }

  String _getRsiStatus(double rsi) {
    if (rsi > 70) return "OVERBOUGHT";
    if (rsi < 30) return "OVERSOLD";
    return "NEUTRAL";
  }

  Widget _buildNoDataUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.query_stats, color: Colors.white10, size: 50),
          const SizedBox(height: 15),
          const Text("SERVER OFFLINE", style: TextStyle(color: Colors.white24, letterSpacing: 1.5, fontSize: 12)),
          TextButton(
            onPressed: _startLiveStream, 
            child: const Text("RECONNECT", style: TextStyle(color: Color(0xFF00FFA3)))
          ),
        ],
      ),
    );
  }
}