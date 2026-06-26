import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/portfolio_item.dart';
import 'api_service.dart';

class PortfolioService extends ChangeNotifier {
  final List<PortfolioItem> _ownedStocks = [];
  final Map<String, WebSocketChannel> _activeSockets = {};

  List<PortfolioItem> get ownedStocks => _ownedStocks;

  double get overallInvestment => _ownedStocks.fold(0, (sum, item) => sum + item.totalInvestment);
  double get overallValue => _ownedStocks.fold(0, (sum, item) => sum + item.currentValue);
  double get overallPnL => overallValue - overallInvestment;
  double get overallPnLPercentage => overallInvestment > 0 ? (overallPnL / overallInvestment) * 100 : 0.0;

  void addPosition(String symbol, int qty, double buyPrice) {
    final cleanSymbol = symbol.trim().toUpperCase();
    if (cleanSymbol.isEmpty || qty <= 0 || buyPrice <= 0) return;

    // Check if position already exists to prevent duplicate stream channels
    final existingIndex = _ownedStocks.indexWhere((item) => item.symbol == cleanSymbol);
    if (existingIndex >= 0) return;

    final newItem = PortfolioItem(
      symbol: cleanSymbol,
      quantity: qty,
      averageBuyPrice: buyPrice,
      currentLivePrice: buyPrice, // Base fallback until first socket broadcast arrives
    );

    _ownedStocks.add(newItem);
    notifyListeners();
    _subscribeToLiveTick(cleanSymbol);
  }

  void _subscribeToLiveTick(String symbol) {
    if (_activeSockets.containsKey(symbol)) return;

    try {
      final wsUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
      final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/live/$symbol'));
      _activeSockets[symbol] = channel;

      channel.stream.listen(
        (message) {
          final Map<String, dynamic> data = jsonDecode(message);
          if (data['current_price'] != null) {
            final targetIndex = _ownedStocks.indexWhere((item) => item.symbol == symbol);
            if (targetIndex >= 0) {
              _ownedStocks[targetIndex].currentLivePrice = data['current_price'].toDouble();
              notifyListeners(); // Drives instant UI state shifts
            }
          }
        },
        onError: (err) => print("❌ Portfolio Stream Error for $symbol: $err"),
        onDone: () => print("🔌 Portfolio Stream Closed for $symbol"),
      );
    } catch (e) {
      print("⚠️ Matrix WebSocket failure: $e");
    }
  }

  @override
  void dispose() {
    for (var channel in _activeSockets.values) {
      channel.sink.close();
    }
    super.dispose();
  }
}