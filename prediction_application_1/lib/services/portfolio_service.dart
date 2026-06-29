import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/portfolio_item.dart';
import 'api_service.dart';
import 'notification_service.dart';
class PortfolioService extends ChangeNotifier {
  final List<PortfolioItem> _ownedStocks = [];
  final Map<String, WebSocketChannel> _activeSockets = {};
  final NotificationService _notificationService = NotificationService();
  final Map<String, Set<int>> _notifiedThresholds = {};
  static const List<int> _profitThresholds = [2, 5, 10, 15, 20];
  final Set<String> _alertEnabledSymbols = {};
  List<PortfolioItem> get ownedStocks => _ownedStocks;
  Set<String> get alertEnabledSymbols => _alertEnabledSymbols;
  double get overallInvestment => _ownedStocks.fold(0, (sum, item) => sum + item.totalInvestment);
  double get overallValue => _ownedStocks.fold(0, (sum, item) => sum + item.currentValue);
  double get overallPnL => overallValue - overallInvestment;
  double get overallPnLPercentage => overallInvestment > 0 ? (overallPnL / overallInvestment) * 100 : 0.0;
  PortfolioService() {
    _notificationService.init();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadPortfolioFromCloud(user.uid);
      } else {
        _clearPortfolio();
      }
    });
  }
  bool isAlertEnabled(String symbol) => _alertEnabledSymbols.contains(symbol);
  void toggleAlert(String symbol) {
    if (_alertEnabledSymbols.contains(symbol)) {
      _alertEnabledSymbols.remove(symbol);
    } else {
      _alertEnabledSymbols.add(symbol);
      _notifiedThresholds[symbol] = {};
    }
    notifyListeners();
  }
  Future<void> _loadPortfolioFromCloud(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('portfolio')
          .get();
      _ownedStocks.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final symbol = data['symbol'] ?? '';
        final qty = data['quantity'] ?? 0;
        final buyPrice = (data['averageBuyPrice'] ?? 0.0).toDouble();
        if (symbol.isNotEmpty && qty > 0) {
          final newItem = PortfolioItem(
            symbol: symbol,
            quantity: qty,
            averageBuyPrice: buyPrice,
            currentLivePrice: buyPrice,
          );
          _ownedStocks.add(newItem);
          _alertEnabledSymbols.add(symbol);
          _notifiedThresholds[symbol] = {};
          _subscribeToLiveTick(symbol);
        }
      }
      notifyListeners();
      print("Synced ${_ownedStocks.length} assets from Firestore.");
    } catch (e) {
      print("Cloud sync error: $e");
    }
  }
  void addPosition(String symbol, int qty, double buyPrice) async {
    final cleanSymbol = symbol.trim().toUpperCase();
    if (cleanSymbol.isEmpty || qty <= 0 || buyPrice <= 0) return;
    final existingIndex = _ownedStocks.indexWhere((item) => item.symbol == cleanSymbol);
    if (existingIndex >= 0) return;
    final newItem = PortfolioItem(
      symbol: cleanSymbol,
      quantity: qty,
      averageBuyPrice: buyPrice,
      currentLivePrice: buyPrice,
    );
    _ownedStocks.add(newItem);
    _alertEnabledSymbols.add(cleanSymbol);
    _notifiedThresholds[cleanSymbol] = {};
    notifyListeners();
    _subscribeToLiveTick(cleanSymbol);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('portfolio')
            .doc(cleanSymbol)
            .set({
          'symbol': cleanSymbol,
          'quantity': qty,
          'averageBuyPrice': buyPrice,
          'addedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Failed to write $cleanSymbol to cloud: $e");
      }
    }
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
              final newPrice = data['current_price'].toDouble();
              _ownedStocks[targetIndex].currentLivePrice = newPrice;
              notifyListeners();
              _checkAndNotifyProfit(_ownedStocks[targetIndex]);
            }
          }
        },
        onError: (err) => print("Portfolio Stream Error for $symbol: $err"),
        onDone: () {
           print("Portfolio Stream Closed for $symbol");
           _activeSockets.remove(symbol);
        }
      );
    } catch (e) {
      print("WebSocket failure for $symbol: $e");
    }
  }
  void _checkAndNotifyProfit(PortfolioItem item) {
    if (!_alertEnabledSymbols.contains(item.symbol)) return;
    final profitPct = item.profitLossPercentage;
    final symbol = item.symbol;
    _notifiedThresholds.putIfAbsent(symbol, () => {});
    for (final threshold in _profitThresholds) {
      if (profitPct >= threshold && !_notifiedThresholds[symbol]!.contains(threshold)) {
        _notifiedThresholds[symbol]!.add(threshold);
        _notificationService.showProfitAlert(
          symbol: symbol,
          profitPercent: profitPct,
          currentPrice: item.currentLivePrice,
          buyPrice: item.averageBuyPrice,
        );
        break;
      }
    }
    if (profitPct <= -2 && !_notifiedThresholds[symbol]!.contains(-2)) {
      _notifiedThresholds[symbol]!.add(-2);
      _notificationService.showStopLossAlert(
        symbol: symbol,
        currentPrice: item.currentLivePrice,
        stopLoss: item.averageBuyPrice * 0.98,
      );
    }
  }
  void _clearPortfolio() {
    _ownedStocks.clear();
    for (var channel in _activeSockets.values) {
      channel.sink.close();
    }
    _activeSockets.clear();
    _alertEnabledSymbols.clear();
    _notifiedThresholds.clear();
    notifyListeners();
  }
  @override
  void dispose() {
    _clearPortfolio();
    super.dispose();
  }
}
