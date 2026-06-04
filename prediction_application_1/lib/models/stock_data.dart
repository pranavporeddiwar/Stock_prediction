class StockData {
  final String symbol;
  final double currentPrice;
  final List<CandleModel> history;
  final List<CandleModel> predictedPath; // UPDATED: Full candles for future graph
  final double sentiment;
  final String suitability;
  final String action;     // "BUY", "SELL", or "HOLD"
  final String reasoning;  // The Trade Thesis from Claude 3 Opus
  final double stopLoss;   // Specific SL Price
  final double targetPrice;// Specific TP Price
  final double rsi;
  final String trendLogic;

  StockData({
    required this.symbol,
    required this.currentPrice,
    required this.history,
    required this.predictedPath,
    required this.sentiment,
    required this.suitability,
    required this.action,
    required this.reasoning,
    required this.stopLoss,
    required this.targetPrice,
    required this.rsi,
    required this.trendLogic,
  });

  factory StockData.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert any number type to double
    double forceDouble(dynamic val) {
      if (val == null) return 0.0;
      return (val as num).toDouble();
    }

    // Parse Nested Risk Object if your backend still uses it, 
    // otherwise these can be mapped directly from the top level.
    var risk = json['dynamic_risk'] ?? {};

    return StockData(
      symbol: json['symbol']?.toString() ?? 'N/A',
      currentPrice: forceDouble(json['current_price']),
      sentiment: forceDouble(json['sentiment']),
      suitability: json['suitability']?.toString() ?? 'ANALYZING...',
      
      // Mapped from Claude 3 Opus response keys
      action: json['action']?.toString() ?? 'HOLD',
      reasoning: json['reasoning']?.toString() ?? 'Analyzing market momentum...',
      
      // If your backend sends specific prices, use those. 
      // Otherwise, it calculates them based on the current price.
      stopLoss: forceDouble(json['stop_loss'] ?? (forceDouble(json['current_price']) * 0.98)),
      targetPrice: forceDouble(json['target_price'] ?? (forceDouble(json['current_price']) * 1.05)),
      
      rsi: forceDouble(json['rsi'] ?? 50.0),
      trendLogic: json['trend_logic']?.toString() ?? 'NEUTRAL_TREND',

      // Parse Historical Candles (Real Data)
      history: (json['history'] as List? ?? [])
          .map((e) => CandleModel.fromJson(e))
          .toList(),
      
      // Parse Predicted Future Candles (The Future Graph)
      predictedPath: (json['future_path'] as List? ?? [])
          .map((e) => CandleModel.fromJson(e))
          .toList(),
    );
  }
}

class CandleModel {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleModel({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  factory CandleModel.fromJson(Map<String, dynamic> json) {
    return CandleModel(
      // Handles potential null or missing timestamps
      time: DateTime.parse(json['time'] ?? DateTime.now().toIso8601String()),
      open: (json['open'] as num? ?? 0.0).toDouble(),
      high: (json['high'] as num? ?? 0.0).toDouble(),
      low: (json['low'] as num? ?? 0.0).toDouble(),
      close: (json['close'] as num? ?? 0.0).toDouble(),
    );
  }
}