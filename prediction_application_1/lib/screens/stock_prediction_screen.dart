import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/api_service.dart';
import '../models/stock_data.dart';
import 'investment_helper_page.dart';
import '../utils/app_state.dart'; // NEW: Import the global context state

class StockPredictionScreen extends StatefulWidget {
  final String symbol;
  const StockPredictionScreen({super.key, required this.symbol});

  @override
  State<StockPredictionScreen> createState() => _StockPredictionScreenState();
}

class _StockPredictionScreenState extends State<StockPredictionScreen> {
  StockData? data;
  bool isLoading = true;
  late TrackballBehavior _trackballBehavior;
  late SelectionBehavior _selectionBehavior;
  late ZoomPanBehavior _zoomPanBehavior; // Ensures the graph isn't squashed

  @override
  void initState() {
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

    _selectionBehavior = SelectionBehavior(
      enable: true,
      unselectedOpacity: 0.4,
    );

    // Initialization for TradingView-style zooming and panning
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.x, 
    );

    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final result = await ApiService().fetchPrediction(widget.symbol, "intraday");
      if (mounted) {
        setState(() {
          data = result;
          isLoading = false;
        });
        
        // --- NEW: UPDATE THE BOT'S BRAIN ---
        // Feeds the exact screen numbers into the background context for the Neural Tutor
        if (data != null && data!.history.isNotEmpty) {
          currentBotContext.value = 
            "User is viewing the prediction screen for ${widget.symbol}. "
            "Current Price: ₹${data!.history.last.close}. "
            "AI Signal: ${data!.action}. "
            "RSI: ${data!.rsi.toStringAsFixed(1)}. "
            "AI Reasoning: ${data!.reasoning}";
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Neural Sync Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasData = data != null && data!.history.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
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
                  child: Column(
                    children: [
                      _buildAdvancedTradingChart(),
                      _buildTradeExecutionCard(),
                      _buildTechnicalInsights(),
                      _buildNeuralReasoning(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAdvancedTradingChart() {
    final int historyCount = data!.history.length;
    
    // Auto-focus on the last 60 candles so they look like real candlesticks
    final double initialVisibleMin = historyCount > 60 
        ? (historyCount - 60).toDouble() 
        : 0.0;
    final double initialVisibleMax = (historyCount + 6).toDouble(); 

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.45, 
      child: SfCartesianChart(
        margin: const EdgeInsets.fromLTRB(5, 15, 5, 10),
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
          anchorRangeToVisiblePoints: true, // Crucial: Fixes the 'squashed to zero' bug
          labelPosition: ChartDataLabelPosition.outside,
          labelStyle: TextStyle(color: Colors.white60, fontSize: 10),
          axisLine: AxisLine(width: 0),
          majorGridLines: MajorGridLines(color: Colors.white10, width: 0.5), 
        ),
        
        series: <CartesianSeries>[
          // 1. HISTORICAL DATA
          CandleSeries<CandleModel, int>(
            dataSource: data!.history,
            xValueMapper: (c, i) => i,
            lowValueMapper: (c, _) => c.low,
            highValueMapper: (c, _) => c.high,
            openValueMapper: (c, _) => c.open,
            closeValueMapper: (c, _) => c.close,
            bullColor: const Color(0xFF00FFA3),
            bearColor: const Color(0xFFFF3E3E),
            enableSolidCandles: true,
            selectionBehavior: _selectionBehavior,
          ),
          // 2. FUTURE PREDICTED PATH
          CandleSeries<CandleModel, int>(
            dataSource: data!.predictedPath,
            xValueMapper: (c, i) => historyCount + i,
            lowValueMapper: (c, _) => c.low,
            highValueMapper: (c, _) => c.high,
            openValueMapper: (c, _) => c.open,
            closeValueMapper: (c, _) => c.close,
            opacity: 0.6,
            dashArray: const <double>[4, 4],
            bullColor: const Color(0xFF00FFA3),
            bearColor: const Color(0xFFFF3E3E),
            enableSolidCandles: false,
          ),
        ],
        
        annotations: <CartesianChartAnnotation>[
          // 1. ENTRY POINT (Buy/Sell Arrow)
          if (data!.action != "HOLD")
            CartesianChartAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data!.action, 
                    style: TextStyle(
                      color: data!.action == "BUY" ? const Color(0xFF00FFA3) : const Color(0xFFFF3E3E), 
                      fontSize: 9, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  Icon(
                    data!.action == "BUY" ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
                    color: data!.action == "BUY" ? const Color(0xFF00FFA3) : const Color(0xFFFF3E3E),
                    size: 28,
                  ),
                ],
              ),
              coordinateUnit: CoordinateUnit.point,
              x: (historyCount - 1).toDouble(),
              y: data!.history.last.low,
            ),
          
          // 2. TARGET POINT (Flag)
          if (data!.predictedPath.isNotEmpty)
            CartesianChartAnnotation(
              widget: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag, color: Colors.orangeAccent, size: 22),
                  Text("TARGET", style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
              coordinateUnit: CoordinateUnit.point,
              x: (historyCount + data!.predictedPath.length - 1).toDouble(),
              y: data!.targetPrice,
            ),
        ],
      ),
    );
  }

  Widget _buildTradeExecutionCard() {
    final bool isBuy = data!.action == "BUY";
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isBuy ? const Color(0xFF002B1B) : const Color(0xFF2B0000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBuy ? const Color(0xFF00FFA3) : Colors.redAccent, 
          width: 1
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("NEURAL SIGNAL", style: TextStyle(color: isBuy ? const Color(0xFF00FFA3) : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(data!.action, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("HYBRID DATA FUSION", 
            style: TextStyle(color: Color(0xFF00FFA3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 15),
          _insightRow("Relative Strength (RSI)", data!.rsi.toStringAsFixed(1), _getRsiStatus(data!.rsi)),
          const Divider(color: Colors.white12, height: 25),
          _insightRow("Stock Sentiment", (data!.sentiment * 100).toStringAsFixed(0) + "%", data!.suitability),
        ],
      ),
    );
  }

  Widget _buildNeuralReasoning() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("GROQ AI THESIS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(data!.reasoning, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6, letterSpacing: 0.3)),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFA3),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentHelperPage(data: data!))),
              child: const Text("PROCEED TO CAPITAL ALLOCATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }

  Widget _insightRow(String label, String value, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Row(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(status, style: TextStyle(
              color: status.contains("BULLISH") || status == "OVERSOLD" ? const Color(0xFF00FFA3) : Colors.orangeAccent,
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
          const Icon(Icons.query_stats, color: Colors.white10, size: 60),
          const SizedBox(height: 20),
          const Text("OFFLINE", style: TextStyle(color: Colors.white24, letterSpacing: 2)),
          TextButton(onPressed: _fetchData, child: const Text("RECONNECT", style: TextStyle(color: Color(0xFF00FFA3)))),
        ],
      ),
    );
  }
}