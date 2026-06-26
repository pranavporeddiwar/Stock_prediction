import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_data.dart';

class ApiService {
  // Centralized endpoint configuration
  // ☁️ Pointed globally to the Render Cloud Engine!
  // Note: Your LiveStreamService will automatically transform 'https' to 'wss' for secure websockets.
  static const String baseUrl = "https://stock-prediction-dqo3.onrender.com";

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

  /// Pulls the broad market overview data array for your unified watchlists.
  /// RENAME FIX: This is now getWatchlistOverview() to match your UI!
  Future<List<dynamic>> getWatchlistOverview() async {
    final url = Uri.parse('$baseUrl/watchlist');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to sync watchlist telemetry matrix.");
      }
    } catch (e) {
      throw Exception("Watchlist Service Offline: $e");
    }
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
          'context': context // Feeds real-time chart data vectors to Llama-3
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
}