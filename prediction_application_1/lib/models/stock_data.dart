class CandleModel {
  final DateTime? time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;
  final String? pattern;
  final String? risk;
  CandleModel({
    this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.pattern,
    this.risk,
  });
  factory CandleModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }
    double closePrice = parseDouble(json['close'], 0.0);
    return CandleModel(
      open: parseDouble(json['open'], closePrice),
      high: parseDouble(json['high'], closePrice),
      low: parseDouble(json['low'], closePrice),
      close: closePrice,
      volume: parseDouble(json['volume'], 0.0),
      pattern: json['pattern']?.toString(),
      risk: json['risk']?.toString(),
    );
  }
}
class StockData {
  final String symbol;
  final double currentPrice;
  final List<CandleModel> history;
  final List<CandleModel> predictedPath;
  final double sentiment;
  final String suitability;
  final String action;
  final String reasoning;
  final double targetPrice;
  final double stopLoss;
  final String buyTime;
  final String sellTime;
  final String tradingStyle;
  final String styleReason;
  final String riskLevel;
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
    required this.targetPrice,
    required this.stopLoss,
    required this.buyTime,
    required this.sellTime,
    required this.tradingStyle,
    required this.styleReason,
    required this.riskLevel,
    required this.rsi,
    required this.trendLogic,
  });
  factory StockData.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }
    return StockData(
      symbol: json['symbol']?.toString() ?? 'UNKNOWN',
      currentPrice: parseDouble(json['current_price'], 0.0),
      history: (json['history'] as List<dynamic>?)?.map((e) {
        if (e is Map<String, dynamic>) return CandleModel.fromJson(e);
        return CandleModel(open: 0, high: 0, low: 0, close: 0);
      }).toList() ?? [],
      predictedPath: (json['future_path'] as List<dynamic>?)?.map((e) {
        if (e is num) return CandleModel.fromJson({'close': e});
        if (e is Map<String, dynamic>) return CandleModel.fromJson(e);
        return CandleModel(open: 0, high: 0, low: 0, close: 0);
      }).toList() ?? [],
      sentiment: parseDouble(json['sentiment'], 0.5),
      suitability: json['suitability']?.toString() ?? 'Neutral',
      action: json['action']?.toString() ?? 'HOLD',
      reasoning: json['reasoning']?.toString() ?? 'Analyzing market momentum...',
      targetPrice: parseDouble(json['target_price'], 0.0),
      stopLoss: parseDouble(json['stop_loss'], 0.0),
      buyTime: json['buy_time']?.toString() ?? '',
      sellTime: json['sell_time']?.toString() ?? '',
      tradingStyle: json['trading_style']?.toString() ?? 'Intraday',
      styleReason: json['style_reason']?.toString() ?? 'Default strategy.',
      riskLevel: json['risk_level']?.toString() ?? 'Medium',
      rsi: parseDouble(json['rsi'], 50.0),
      trendLogic: json['trendLogic']?.toString() ?? 'Standard tracking',
    );
  }
}
