import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;
import '../models/stock_data.dart';

class ApiService {
  // Update this with your current IPv4 address
  final String baseUrl = "http://192.168.1.78:8000"; 

  // --- THREADING WORKERS (Top-Level Functions) ---
  // These must stay static or top-level to be used in 'compute'
  static StockData _parseStockData(String responseBody) {
    final Map<String, dynamic> jsonData = json.decode(responseBody);
    return StockData.fromJson(jsonData);
  }

  static List<dynamic> _parseWatchlist(String responseBody) {
    return json.decode(responseBody) as List<dynamic>;
  }

  /// Fetches detailed prediction data using Background Isolates
  Future<StockData?> fetchPrediction(String symbol, String mode) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/predict?symbol=$symbol&mode=$mode"),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        // PARALLELISM: Spawns a new Isolate to decode JSON
        // This prevents the UI thread from dropping frames
        return await compute(_parseStockData, response.body);
      } else {
        debugPrint("⚠️ Server error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Threading Error (API): $e");
      return null;
    }
  }

  /// Fetches watchlist summary data
  Future<List<dynamic>> getWatchlistOverview() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/watchlist")
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Keeps the watchlist scroll perfectly smooth
        return await compute(_parseWatchlist, response.body);
      } else {
        return [];
      }
    } catch (e) {
      debugPrint("❌ Watchlist Thread Error: $e");
      return [];
    }
  }
}