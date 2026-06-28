import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_data.dart';

class ApiService {
  // Centralized endpoint configuration
  // ☁️ Pointed globally to the Render Cloud Engine!
  // Note: Your LiveStreamService will automatically transform 'https' to 'wss' for secure websockets.
  static const String baseUrl = "http://192.168.1.73:8001";

  /// Fetches the initial heavy structural data snapshot from the backend.
  Future<StockData> fetchPrediction(String symbol, String mode) async {
    final url = Uri.parse('$baseUrl/predict?symbol=${symbol.toUpperCase()}&mode=$mode');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        return StockData.fromJson(decodedData);
      } else {
        throw Exception("Server responded with status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Neural Bridge Connectivity Failure: $e");
    }
  }

  /// Pulls the broad market overview data with enriched trading style analysis.
  Future<List<Map<String, dynamic>>> getWatchlistOverview() async {
    final url = Uri.parse('$baseUrl/watchlist');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> rawList;

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          List<dynamic>? found;
          for (final key in ['stocks', 'data', 'watchlist', 'results', 'items']) {
            if (decoded[key] is List) { found = decoded[key] as List<dynamic>; break; }
          }

          if (found != null) {
            rawList = found;
          } else if (decoded.values.every((v) => v is Map)) {
            rawList = decoded.entries.map<Map<String, dynamic>>((e) {
              final val = Map<String, dynamic>.from(e.value as Map);
              val['symbol'] = e.key.toString();
              return val;
            }).toList();
          } else {
            rawList = decoded.values.whereType<List>().toList().isNotEmpty
                ? decoded.values.whereType<List>().first
                : [decoded];
          }
        } else {
          rawList = [];
        }

        // Return enriched data with all trading style fields
        return rawList.map<Map<String, dynamic>>((item) {
          if (item is Map) {
            return {
              'symbol': (item['symbol'] ?? item['ticker'] ?? item['name'] ?? 'UNKNOWN').toString(),
              'price':  _parseDouble(item['current_price'] ?? item['price'] ?? item['ltp'] ?? item['close'] ?? 0),
              'signal': (item['status'] ?? item['signal'] ?? item['action'] ?? 'VIEW').toString(),
              'change_pct': _parseDouble(item['change_pct'] ?? 0),
              'rsi': _parseDouble(item['rsi'] ?? 50),
              'volatility': _parseDouble(item['volatility'] ?? 0),
              'trading_style': (item['trading_style'] ?? 'Intraday').toString(),
              'style_reason': (item['style_reason'] ?? '').toString(),
            };
          } else if (item is String) {
            return {'symbol': item, 'price': 0.0, 'signal': 'VIEW', 'change_pct': 0.0, 'rsi': 50.0, 'volatility': 0.0, 'trading_style': 'Intraday', 'style_reason': ''};
          }
          return {'symbol': 'UNKNOWN', 'price': 0.0, 'signal': 'VIEW', 'change_pct': 0.0, 'rsi': 50.0, 'volatility': 0.0, 'trading_style': 'Intraday', 'style_reason': ''};
        }).toList();

      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Watchlist Service Offline: $e");
    }
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// Sends a user chat message alongside their precise reactive viewport context
  /// straight to the unified FastAPI /chat endpoint.
  Future<String> sendChatMessage(String message, String context) async {
    final url = Uri.parse('$baseUrl/chat');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message, 
          'context': context
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['reply'] ?? "The neural network returned an empty synthesis state.";
      } else {
        throw Exception("Server rejected chat payload with status: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Neural Tutor Node unreachable: $e");
    }
  }

  /// Fetches real-time market news from yfinance via the backend.
  Future<List<Map<String, dynamic>>> getMarketNews() async {
    final url = Uri.parse('$baseUrl/news');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> newsList = decoded['news'] ?? [];
        return newsList.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }
      return [];
    } catch (e) {
      print("News fetch error: $e");
      return [];
    }
  }

  /// Fetches overall market momentum (Nifty 50 + Sensex trends).
  Future<Map<String, dynamic>> getMarketMomentum() async {
    final url = Uri.parse('$baseUrl/market-momentum');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return _defaultMomentum();
    } catch (e) {
      print("Momentum fetch error: $e");
      return _defaultMomentum();
    }
  }

  Map<String, dynamic> _defaultMomentum() {
    return {
      'state': 'NEUTRAL',
      'momentum': 'LOADING',
      'nifty_change': 0.0,
      'summary': 'Fetching market data...',
      'strategy': 'Loading...',
    };
  }
}