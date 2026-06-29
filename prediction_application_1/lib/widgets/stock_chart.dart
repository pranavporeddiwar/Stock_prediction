import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../models/stock_data.dart';
import '../services/api_service.dart';
class SmartStockScreen extends StatefulWidget {
  final String symbol;
  const SmartStockScreen({super.key, required this.symbol});
  @override
  State<SmartStockScreen> createState() => _SmartStockScreenState();
}
class _SmartStockScreenState extends State<SmartStockScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<CandleModel> _historyData = [];
  List<CandleModel> _futurePath = [];
  double? _targetPrice;
  double? _stopLoss;
  String? _action;
  String? _reasoning;
  @override
  void initState() {
    super.initState();
    _fetchDataFromPython();
  }
  Future<void> _fetchDataFromPython() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final url = Uri.parse('${ApiService.baseUrl}/predict?symbol=${widget.symbol}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<CandleModel> parsedCandles = [];
        for (var item in data['history']) {
           parsedCandles.add(CandleModel(
             time: item['time'] != null ? DateTime.parse(item['time']) : null,
             open: item['open'].toDouble(),
             high: item['high'].toDouble(),
             low: item['low'].toDouble(),
             close: item['close'].toDouble(),
             volume: item['volume']?.toDouble() ?? 0.0,
           ));
        }
        if (parsedCandles.length > 20) {
          parsedCandles = parsedCandles.sublist(parsedCandles.length - 20);
        }
        List<CandleModel> parsedFuture = [];
        if (data['future_path'] != null && parsedCandles.isNotEmpty) {
          final lastRealClose = parsedCandles.last.close;
          List<double> rawCloses = [];
          for (var item in data['future_path']) {
            double val = (item is num) ? item.toDouble() : (item['close'] as num).toDouble();
            rawCloses.add(val);
          }
          if (rawCloses.length > 8) {
            rawCloses = rawCloses.sublist(0, 8);
          }
          if (rawCloses.isNotEmpty) {
            final rawBase = rawCloses.first;
            final offset = lastRealClose - rawBase;
            double prevClose = lastRealClose;
            for (int i = 0; i < rawCloses.length; i++) {
              double normalizedClose = rawCloses[i] + offset;
              double open = prevClose;
              double close = normalizedClose;
              double diff = (close - open).abs();
              double wickSize = diff * 0.3 + (lastRealClose * 0.001);
              double high = max(open, close) + wickSize;
              double low = min(open, close) - wickSize;
              parsedFuture.add(CandleModel(
                open: open, high: high, low: low, close: close, volume: 0,
                time: parsedCandles.last.time?.add(Duration(minutes: 15 * (i + 1))),
              ));
              prevClose = normalizedClose;
            }
          }
        }
        setState(() {
          _historyData = parsedCandles;
          _futurePath = parsedFuture;
          _targetPrice = data['target_price']?.toDouble();
          _stopLoss = data['stop_loss']?.toDouble();
          _action = data['action'];
          _reasoning = data['reasoning'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Python Server Error: ${response.statusCode}\nIs the server running?";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Could not connect to Python Server.\nMake sure you updated the IP address!\nError: $e";
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        title: Text(widget.symbol, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchDataFromPython,
          )
        ],
      ),
      body: _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF2962FF)),
                SizedBox(height: 16),
                Text("Analyzing AI Strategy...", style: TextStyle(color: Colors.white54)),
              ],
            ),
          )
        : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(_errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
                      onPressed: _fetchDataFromPython,
                      child: const Text("RECONNECT", style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: StockChart(
                historyData: _historyData,
                futureData: _futurePath,
                aiTargetPrice: _targetPrice,
                suggestedBuyPrice: _action == "BUY" && _historyData.isNotEmpty ? _targetPrice : null,
                suggestedBuyTime: _action == "BUY" ? DateTime.now() : null,
                buyReasoning: _action == "BUY" ? _reasoning : null,
                suggestedSellPrice: _action == "SELL" && _historyData.isNotEmpty ? _targetPrice : null,
                suggestedSellTime: _action == "SELL" ? DateTime.now() : null,
                sellReasoning: _action == "SELL" ? _reasoning : null,
                stopLoss: _stopLoss,
              ),
            ),
    );
  }
}
class StockChart extends StatelessWidget {
  final List<CandleModel> historyData;
  final List<CandleModel> futureData;
  final double? aiTargetPrice;
  final DateTime? suggestedBuyTime;
  final double? suggestedBuyPrice;
  final String? buyReasoning;
  final DateTime? suggestedSellTime;
  final double? suggestedSellPrice;
  final String? sellReasoning;
  final double? stopLoss;
  const StockChart({
    super.key,
    required this.historyData,
    required this.futureData,
    this.aiTargetPrice,
    this.suggestedBuyTime,
    this.suggestedBuyPrice,
    this.buyReasoning,
    this.suggestedSellTime,
    this.suggestedSellPrice,
    this.sellReasoning,
    this.stopLoss,
  });
  static const _bgColor      = Color(0xFF131722);
  static const _gridColor    = Color(0xFF1E222D);
  static const _bullColor    = Color(0xFF26A69A);
  static const _bearColor    = Color(0xFFEF5350);
  static const _textColor    = Color(0xFF9598A1);
  static const _priceTagColor = Color(0xFF2962FF);
  static const _aiLineColor  = Color(0xFF2962FF);
  @override
  Widget build(BuildContext context) {
    if (historyData.isEmpty) {
      return _emptyState();
    }
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          SizedBox(
            height: 360,
            child: CustomPaint(
              painter: CandleChartPainter(
                candles: historyData,
                futureData: futureData,
                aiTargetPrice: aiTargetPrice,
                suggestedBuyPrice: suggestedBuyPrice,
                suggestedSellPrice: suggestedSellPrice,
                stopLoss: stopLoss,
                bullColor: _bullColor,
                bearColor: _bearColor,
                gridColor: _gridColor,
                textColor: _textColor,
                priceTagColor: _priceTagColor,
                aiLineColor: _aiLineColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showTradeStrategyDialog(context),
                icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                label: const Text(
                  "View AI Trade Strategy",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _aiLineColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
  void _showTradeStrategyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E222D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.query_stats, color: Color(0xFF2962FF)),
              SizedBox(width: 8),
              Text(
                "AI Strategy Signal",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Tap a signal to view AI reasoning.",
                style: TextStyle(color: Color(0xFF9598A1), fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              _buildTradeRow(context, "BUY", suggestedBuyPrice, suggestedBuyTime, _bullColor, buyReasoning),
              const Divider(color: Color(0xFF2B3139), height: 24, thickness: 1),
              _buildTradeRow(context, "SELL", suggestedSellPrice, suggestedSellTime, _bearColor, sellReasoning),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("CLOSE", style: TextStyle(color: Color(0xFF9598A1))),
            ),
          ],
        );
      },
    );
  }
  void _showReasoningDialog(BuildContext context, String action, String reasoning, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131722),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.5), width: 1),
          ),
          title: Row(
            children: [
              Icon(Icons.psychology, color: color),
              const SizedBox(width: 8),
              Text(
                "$action Rationale",
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            reasoning,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("GOT IT", style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
  Widget _buildTradeRow(BuildContext context, String action, double? price, DateTime? time, Color color, String? reasoning) {
    final hasData = price != null && time != null;
    String formattedDate = hasData
        ? '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}'
        : '--';
    String formattedTime = hasData
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '--';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (hasData && reasoning != null && reasoning.isNotEmpty) {
            _showReasoningDialog(context, action, reasoning, color);
          } else if (!hasData) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Awaiting AI Analysis Data...")),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  action,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasData ? '₹${price.toStringAsFixed(2)}' : 'Awaiting Data...',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF9598A1), size: 12),
                        const SizedBox(width: 4),
                        Text(formattedDate, style: const TextStyle(color: Color(0xFF9598A1), fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, color: Color(0xFF9598A1), size: 12),
                        const SizedBox(width: 4),
                        Text(formattedTime, style: const TextStyle(color: Color(0xFF9598A1), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.info_outline, color: hasData ? color : const Color(0xFF434651), size: 20),
            ],
          ),
        ),
      ),
    );
  }
  Widget _header() {
    final last = historyData.last;
    final isUp = last.close >= last.open;
    final change = last.close - last.open;
    final changePct = (change / last.open * 100);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          const Text(
            'NSE · 1',
            style: TextStyle(color: Color(0xFFB2B5BE), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
          ),
          const SizedBox(width: 10),
          _ohlcLabel('O', last.open),
          _ohlcLabel('H', last.high),
          _ohlcLabel('L', last.low),
          _ohlcLabel('C', last.close),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isUp ? _bullColor.withOpacity(0.15) : _bearColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${isUp ? '+' : ''}${change.toStringAsFixed(2)} (${changePct.toStringAsFixed(2)}%)',
              style: TextStyle(color: isUp ? _bullColor : _bearColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  Widget _ohlcLabel(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label ', style: const TextStyle(color: Color(0xFF636870), fontSize: 10)),
            TextSpan(text: value.toStringAsFixed(2), style: const TextStyle(color: Color(0xFFB2B5BE), fontSize: 10)),
          ],
        ),
      ),
    );
  }
  Widget _emptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(12)),
      child: const Center(
        child: Text('No Data Available', style: TextStyle(color: Color(0xFF9598A1), fontSize: 13)),
      ),
    );
  }
}
class CandleChartPainter extends CustomPainter {
  final List<CandleModel> candles;
  final List<CandleModel> futureData;
  final double? aiTargetPrice;
  final double? suggestedBuyPrice;
  final double? suggestedSellPrice;
  final double? stopLoss;
  final Color bullColor, bearColor, gridColor, textColor, priceTagColor, aiLineColor;
  static const double _priceAxisWidth = 68.0;
  static const double _timeAxisHeight = 22.0;
  static const int _gridLines = 5;
  CandleChartPainter({
    required this.candles,
    required this.futureData,
    required this.aiTargetPrice,
    this.suggestedBuyPrice,
    this.suggestedSellPrice,
    this.stopLoss,
    required this.bullColor,
    required this.bearColor,
    required this.gridColor,
    required this.textColor,
    required this.priceTagColor,
    required this.aiLineColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _priceAxisWidth;
    final candleH = size.height - _timeAxisHeight;
    final candleArea = Rect.fromLTWH(0, 0, chartW, candleH);
    final allCandles = [...candles, ...futureData];
    if (allCandles.isEmpty) return;
    double minPrice = allCandles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    double maxPrice = allCandles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final priceRange = (maxPrice - minPrice) == 0 ? 1.0 : (maxPrice - minPrice);
    final pad = priceRange * 0.10;
    final pMin = minPrice - pad;
    final pMax = maxPrice + pad;
    final pRange = pMax - pMin;
    double priceToY(double price) => candleArea.bottom - ((price - pMin) / pRange) * candleArea.height;
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    final axisTextStyle = TextStyle(color: textColor, fontSize: 9.5, fontFamily: 'monospace');
    for (int i = 0; i <= _gridLines; i++) {
      final y = candleArea.top + (candleArea.height / _gridLines) * i;
      canvas.drawLine(Offset(0, y), Offset(chartW, y), gridPaint);
      final price = pMax - (pRange / _gridLines) * i;
      _drawText(canvas, price.toStringAsFixed(1), Offset(chartW + 4, y - 6), axisTextStyle);
    }
    final n = allCandles.length;
    final slotW = chartW / n;
    final bodyW = (slotW * 0.7).clamp(4.0, 16.0);
    final wickW = (bodyW * 0.15).clamp(1.0, 2.5);
    final historyLen = candles.length;
    if (futureData.isNotEmpty && candles.isNotEmpty) {
       final startAiX = slotW * historyLen;
       final bgPaint = Paint()..color = aiLineColor.withOpacity(0.04)..style = PaintingStyle.fill;
       canvas.drawRect(Rect.fromLTWH(startAiX, 0, chartW - startAiX, candleH), bgPaint);
       final dashP = Paint()..color = aiLineColor.withOpacity(0.6)..strokeWidth = 1.2;
       _drawDashedLine(canvas, Offset(startAiX, 0), Offset(startAiX, candleH), dashP);
       final tagBg = RRect.fromRectAndRadius(
         Rect.fromLTWH(startAiX + 3, 4, 32, 16), const Radius.circular(4));
       canvas.drawRRect(tagBg, Paint()..color = aiLineColor.withOpacity(0.9));
       _drawText(canvas, "AI →", Offset(startAiX + 6, 6),
         const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold));
    }
    double? buyIndicatorX, buyIndicatorY;
    double? sellIndicatorX, sellIndicatorY;
    double? lowestFutureClose, highestFutureClose;
    for (int i = 0; i < n; i++) {
      final c = allCandles[i];
      final isFuture = i >= historyLen;
      final cx = slotW * i + slotW / 2;
      final isBull = c.close >= c.open;
      final paintColor = isBull ? bullColor : bearColor;
      final bodyTop    = priceToY(isBull ? c.close : c.open);
      final bodyBottom = priceToY(isBull ? c.open  : c.close);
      final bodyHeight = (bodyBottom - bodyTop).abs().clamp(1.0, double.infinity);
      if (isFuture) {
        if (lowestFutureClose == null || c.close < lowestFutureClose) {
          lowestFutureClose = c.close;
          buyIndicatorX = cx;
          buyIndicatorY = priceToY(c.low);
        }
        if (highestFutureClose == null || c.close > highestFutureClose) {
          highestFutureClose = c.close;
          sellIndicatorX = cx;
          sellIndicatorY = priceToY(c.high);
        }
      }
      final candleRect = Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bodyHeight);
      if (isFuture) {
        final fillPaint = Paint()..color = paintColor.withOpacity(0.18)..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(candleRect, const Radius.circular(1)), fillPaint);
        final borderPaint = Paint()..color = paintColor.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 1.2;
        canvas.drawRRect(RRect.fromRectAndRadius(candleRect, const Radius.circular(1)), borderPaint);
        final wickPaint = Paint()..color = paintColor.withOpacity(0.6)..strokeWidth = 1.0;
        _drawDashedLine(canvas, Offset(cx, priceToY(c.high)), Offset(cx, bodyTop), wickPaint);
        _drawDashedLine(canvas, Offset(cx, bodyBottom), Offset(cx, priceToY(c.low)), wickPaint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(candleRect, const Radius.circular(1)),
          Paint()..color = paintColor,
        );
        final wickPaint = Paint()..color = paintColor..strokeWidth = wickW;
        canvas.drawLine(Offset(cx, priceToY(c.high)), Offset(cx, bodyTop), wickPaint);
        canvas.drawLine(Offset(cx, bodyBottom), Offset(cx, priceToY(c.low)), wickPaint);
      }
      if (i % (n ~/ 5).clamp(1, 8) == 0 && c.time != null) {
        final t = c.time!;
        final label = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        _drawText(canvas, label, Offset(cx - 14, size.height - _timeAxisHeight + 4), axisTextStyle);
      }
    }
    if (candles.isNotEmpty) {
      final lastPrice = candles.last.close;
      final lastY = priceToY(lastPrice);
      final isLastBull = candles.last.close >= candles.last.open;
      final lineColor = isLastBull ? bullColor : bearColor;
      _drawDashedLine(canvas, Offset(0, lastY), Offset(chartW, lastY),
        Paint()..color = lineColor.withOpacity(0.4)..strokeWidth = 0.8);
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(chartW + 1, lastY - 9, _priceAxisWidth - 2, 18), const Radius.circular(3));
      canvas.drawRRect(badgeRect, Paint()..color = lineColor);
      _drawText(canvas, lastPrice.toStringAsFixed(1), Offset(chartW + 5, lastY - 6),
        const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold));
    }
    if (suggestedBuyPrice != null && buyIndicatorX != null && buyIndicatorY != null) {
      final buyY = buyIndicatorY! + 16;
      canvas.drawCircle(Offset(buyIndicatorX!, buyY), 10, Paint()..color = bullColor);
      final bPainter = TextPainter(
        text: const TextSpan(text: "B", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      bPainter.paint(canvas, Offset(buyIndicatorX! - bPainter.width / 2, buyY - bPainter.height / 2));
      final buyTagY = priceToY(suggestedBuyPrice!);
      _drawDashedLine(canvas, Offset(0, buyTagY), Offset(chartW, buyTagY),
        Paint()..color = bullColor.withOpacity(0.5)..strokeWidth = 1.0);
      final tagText = "BUY ${suggestedBuyPrice!.toStringAsFixed(1)}";
      final tp = TextPainter(
        text: TextSpan(text: tagText, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      final tw = tp.width + 10;
      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(chartW + 2, buyTagY - 9, tw.clamp(_priceAxisWidth - 4, double.infinity), 18), const Radius.circular(4));
      canvas.drawRRect(tagRect, Paint()..color = bullColor);
      tp.paint(canvas, Offset(chartW + 6, buyTagY - tp.height / 2));
    }
    if (suggestedSellPrice != null && sellIndicatorX != null && sellIndicatorY != null) {
      final sellY = sellIndicatorY! - 16;
      canvas.drawCircle(Offset(sellIndicatorX!, sellY), 10, Paint()..color = bearColor);
      final sPainter = TextPainter(
        text: const TextSpan(text: "S", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      sPainter.paint(canvas, Offset(sellIndicatorX! - sPainter.width / 2, sellY - sPainter.height / 2));
      final sellTagY = priceToY(suggestedSellPrice!);
      _drawDashedLine(canvas, Offset(0, sellTagY), Offset(chartW, sellTagY),
        Paint()..color = bearColor.withOpacity(0.5)..strokeWidth = 1.0);
      final tagText = "SELL ${suggestedSellPrice!.toStringAsFixed(1)}";
      final tp = TextPainter(
        text: TextSpan(text: tagText, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      final tw = tp.width + 10;
      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(chartW + 2, sellTagY - 9, tw.clamp(_priceAxisWidth - 4, double.infinity), 18), const Radius.circular(4));
      canvas.drawRRect(tagRect, Paint()..color = bearColor);
      tp.paint(canvas, Offset(chartW + 6, sellTagY - tp.height / 2));
    }
    if (stopLoss != null) {
      final slY = priceToY(stopLoss!);
      _drawDashedLine(canvas, Offset(0, slY), Offset(chartW, slY),
        Paint()..color = const Color(0xFFFF9800).withOpacity(0.5)..strokeWidth = 0.8);
      final slTag = "SL ${stopLoss!.toStringAsFixed(1)}";
      final slPainter = TextPainter(
        text: TextSpan(text: slTag, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      final slW = slPainter.width + 8;
      final slRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(chartW + 2, slY - 8, slW.clamp(_priceAxisWidth - 4, double.infinity), 16), const Radius.circular(3));
      canvas.drawRRect(slRect, Paint()..color = const Color(0xFFFF9800));
      slPainter.paint(canvas, Offset(chartW + 6, slY - slPainter.height / 2));
    }
  }
  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 4.0;
    const gapLen  = 3.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = (Offset(dx, dy)).distance;
    if (dist == 0) return;
    final steps = (dist / (dashLen + gapLen)).floor();
    final ux = dx / dist;
    final uy = dy / dist;
    for (int i = 0; i < steps; i++) {
      final startD = i * (dashLen + gapLen);
      final endD   = startD + dashLen;
      canvas.drawLine(Offset(p1.dx + ux * startD, p1.dy + uy * startD), Offset(p1.dx + ux * endD, p1.dy + uy * endD), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CandleChartPainter old) =>
      old.candles != candles ||
      old.futureData != futureData ||
      old.aiTargetPrice != aiTargetPrice ||
      old.suggestedBuyPrice != suggestedBuyPrice ||
      old.suggestedSellPrice != suggestedSellPrice ||
      old.stopLoss != stopLoss;
}
