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
  
  final LiveStreamService _streamService = LiveStreamService();
  StreamSubscription? _streamSubscription;
  late TrackballBehavior _trackballBehavior;

  // Theme Colors matching mockup exactly
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
  }

  void _startLiveStream() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final initialData = await ApiService().fetchPrediction(widget.symbol, "intraday");
      if (mounted) setState(() { data = initialData; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      return; 
    }

    _streamSubscription = _streamService.connectToLiveStream(widget.symbol).listen((liveData) {
      if (mounted && data != null) {
        setState(() {
          data = StockData(
            symbol: data!.symbol, currentPrice: liveData.currentPrice,
            history: liveData.history, predictedPath: liveData.predictedPath,
            sentiment: data!.sentiment, suitability: data!.suitability,
            action: data!.action, reasoning: data!.reasoning, 
            stopLoss: data!.stopLoss, targetPrice: data!.targetPrice,
            rsi: liveData.rsi, trendLogic: liveData.trendLogic,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _streamService.disconnect();
    super.dispose();
  }

  // Helper to safely build future OHLC data if backend only sends Close prices
  List<ChartNode> _buildForecastNodes(DateTime cutoffTime, double lastClose) {
    List<ChartNode> nodes = [];
    Random rand = Random(42); 
    
    for (int i = 0; i < data!.predictedPath.length; i++) {
      DateTime time = cutoffTime.add(Duration(minutes: 15 * (i + 1)));
      var c = data!.predictedPath[i];
      
      // If your backend isn't sending OHLC for predictions yet, we simulate standard wicks
      double pClose = c.close;
      double pOpen = i == 0 ? lastClose : data!.predictedPath[i - 1].close;
      double variance = pClose * 0.002; // 0.2% variance for wicks
      double pHigh = max(pOpen, pClose) + (rand.nextDouble() * variance);
      double pLow = min(pOpen, pClose) - (rand.nextDouble() * variance);

      // Simulate pattern assignment if missing
      String pattern = i == 0 ? "Hammer" : (i == 1 ? "Bull Engulf" : (i == 2 ? "Marubozu" : "Doji"));
      String risk = i < 2 ? "Low risk" : (i < 4 ? "Med risk" : "High risk");

      nodes.add(ChartNode(
        time: time, open: pOpen, high: pHigh, low: pLow, close: pClose, 
        isPredicted: true, pattern: pattern, risk: risk
      ));
    }
    return nodes;
  }

  @override
  Widget build(BuildContext context) {
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
      body: isLoading 
          ? Center(child: CircularProgressIndicator(color: neonGreen))
          : (data == null || data!.history.isEmpty) 
              ? const Center(child: Text("Data Offline", style: TextStyle(color: Colors.white54)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderPrice(),
                      _buildChartSection(),
                      _buildImmediatePredictionCard(),
                      _buildConfidenceAndActionCards(),
                      _buildUpcomingForecastList(),
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
          // Timeframe Selector Chips
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

  Widget _buildChartSection() {
    List<ChartNode> historyNodes = [];
    DateTime currentTime = DateTime.now();

    // Map Historical Data
    for (int i = 0; i < data!.history.length; i++) {
      DateTime time = currentTime.subtract(Duration(minutes: 15 * (data!.history.length - 1 - i)));
      var c = data!.history[i];
      historyNodes.add(ChartNode(time: time, open: c.open, high: c.high, low: c.low, close: c.close));
    }

    DateTime cutoffTime = historyNodes.isNotEmpty ? historyNodes.last.time : currentTime;
    double lastClose = historyNodes.isNotEmpty ? historyNodes.last.close : 0.0;
    
    // Generate/Map Predicted Data
    List<ChartNode> forecastNodes = _buildForecastNodes(cutoffTime, lastClose);

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: SfCartesianChart(
            margin: const EdgeInsets.fromLTRB(10, 20, 10, 10),
            plotAreaBorderWidth: 0,
            trackballBehavior: _trackballBehavior,
            
            // ⚡ FIXED: Added explicit Annotations instead of PlotBand text to bypass version errors
            annotations: <CartesianChartAnnotation>[
              CartesianChartAnnotation(
                widget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF2B3139), borderRadius: BorderRadius.circular(4)),
                  child: const Text('AI →', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                coordinateUnit: CoordinateUnit.point,
                x: cutoffTime,
                y: data!.currentPrice,
              ),
              CartesianChartAnnotation(
                widget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: neonRed, borderRadius: BorderRadius.circular(4)),
                  child: Text('SELL ${data!.targetPrice.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                coordinateUnit: CoordinateUnit.point,
                x: cutoffTime,
                y: data!.targetPrice,
              ),
              CartesianChartAnnotation(
                widget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: neonGreen, borderRadius: BorderRadius.circular(4)),
                  child: Text('BUY ${data!.currentPrice.toStringAsFixed(1)}', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                coordinateUnit: CoordinateUnit.point,
                x: cutoffTime,
                y: data!.targetPrice * 0.96,
              ),
            ],
            
            primaryXAxis: DateTimeAxis(
              dateFormat: DateFormat('HH:mm'),
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
              plotBands: <PlotBand>[
                PlotBand(
                  isVisible: true,
                  start: cutoffTime, 
                  end: cutoffTime,
                  borderColor: const Color(0xFF2B3139), 
                  borderWidth: 2, 
                  dashArray: const <double>[5, 5],
                  // ⚡ Removed 'text' properties here to fix your compilation error
                )
              ],
            ),
            primaryYAxis: NumericAxis(
              opposedPosition: true, isVisible: true,
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
              axisLine: const AxisLine(width: 0), 
              majorGridLines: const MajorGridLines(color: Colors.white10, width: 1, dashArray: <double>[4, 4]),
              plotBands: <PlotBand>[
                PlotBand(
                  isVisible: true,
                  start: data!.targetPrice, end: data!.targetPrice,
                  borderColor: neonRed, borderWidth: 1, dashArray: const <double>[4, 4],
                  // ⚡ Removed 'text' properties here to fix your compilation error
                ),
                PlotBand(
                  isVisible: true,
                  start: data!.targetPrice * 0.96, end: data!.targetPrice * 0.96,
                  borderColor: neonGreen, borderWidth: 1, dashArray: const <double>[4, 4],
                  // ⚡ Removed 'text' properties here to fix your compilation error
                )
              ],
            ),
            series: <CartesianSeries>[
              // HISTORICAL SOLID CANDLES
              CandleSeries<ChartNode, DateTime>(
                dataSource: historyNodes, xValueMapper: (n, _) => n.time,
                lowValueMapper: (n, _) => n.low, highValueMapper: (n, _) => n.high,
                openValueMapper: (n, _) => n.open, closeValueMapper: (n, _) => n.close,
                bullColor: neonGreen, bearColor: neonRed,
                enableSolidCandles: true,
              ),
              // FUTURE DASHED HOLLOW CANDLES
              CandleSeries<ChartNode, DateTime>(
                dataSource: forecastNodes, xValueMapper: (n, _) => n.time,
                lowValueMapper: (n, _) => n.low, highValueMapper: (n, _) => n.high,
                openValueMapper: (n, _) => n.open, closeValueMapper: (n, _) => n.close,
                bullColor: Colors.transparent, bearColor: Colors.transparent,
                borderWidth: 2, dashArray: const <double>[3, 3],
                pointColorMapper: (n, _) => n.close >= n.open ? neonGreen : neonRed,
              ),
              // EXECUTION MARKER (BUY BUBBLE)
              if (historyNodes.isNotEmpty)
                ScatterSeries<ChartNode, DateTime>(
                  dataSource: [historyNodes.last], xValueMapper: (n, _) => n.time, yValueMapper: (n, _) => n.low * 0.99,
                  markerSettings: MarkerSettings(shape: DataMarkerType.circle, color: neonGreen, height: 22, width: 22),
  
                  // THIS IS THE FIX:
                  dataLabelMapper: (ChartNode n, _) => "B",
                  dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                  labelAlignment: ChartDataLabelAlignment.middle,
                  ),
                ),
              // EXECUTION MARKER (SELL BUBBLE)
              if (forecastNodes.length > 3)
                ScatterSeries<ChartNode, DateTime>(
                  dataSource: [forecastNodes[2]], xValueMapper: (n, _) => n.time, yValueMapper: (n, _) => n.high * 1.01,
                  markerSettings: MarkerSettings(shape: DataMarkerType.circle, color: neonRed, height: 22, width: 22),
                  dataLabelMapper: (ChartNode n, _) => "S",
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    labelAlignment: ChartDataLabelAlignment.middle,
                  ),
                ),
            ],
          ),
        ),
        // Legend below chart
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(neonGreen, "Bullish"),
            const SizedBox(width: 15),
            _buildLegendDot(neonRed, "Bearish"),
            const SizedBox(width: 15),
            _buildLegendDot(Colors.transparent, "Predicted", borderColor: neonGreen, isDashed: true),
          ],
        )
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label, {Color? borderColor, bool isDashed = false}) {
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

  Widget _buildImmediatePredictionCard() {
    if (data!.predictedPath.isEmpty) return const SizedBox.shrink();
    
    ChartNode firstFuture = _buildForecastNodes(DateTime.now(), data!.currentPrice).first;

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

  Widget _buildConfidenceAndActionCards() {
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
                      Text("₹${data!.currentPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Today • ${DateFormat('HH:mm a').format(DateTime.now())}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      const SizedBox(height: 4),
                      const Text("Hammer + vol spike", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                      Text("₹${data!.targetPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Today • ${DateFormat('HH:mm a').format(DateTime.now().add(const Duration(hours: 1)))}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      const SizedBox(height: 4),
                      const Text("Shooting Star reversal", style: TextStyle(color: Colors.white70, fontSize: 11)),
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

  Widget _buildUpcomingForecastList() {
    List<ChartNode> forecastNodes = _buildForecastNodes(DateTime.now(), data!.currentPrice);
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
              Color riskColor = index < 2 ? neonGreen : (index < 4 ? Colors.orange : neonRed);
              String actLabel = index == 0 ? "BUY" : (index == 3 ? "SELL" : "");

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: index == 0 ? Border.all(color: neonGreen.withOpacity(0.5)) : Border.all(color: Colors.white.withOpacity(0.05)),
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
                          Icon(index < 2 ? Icons.shield_outlined : Icons.warning_amber_rounded, color: riskColor, size: 12),
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
}