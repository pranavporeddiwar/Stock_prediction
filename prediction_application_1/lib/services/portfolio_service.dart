import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ☁️ INJECTED
import 'package:firebase_auth/firebase_auth.dart';     // 🔐 INJECTED
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

  PortfolioService() {
    // ⚡ THE SYNC ENGINE: Listen for Login/Logout events
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadPortfolioFromCloud(user.uid);
      } else {
        _clearPortfolio();
      }
    });
  }

  // 📥 DOWNLOAD FROM CLOUD
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
          
          // Re-establish the WebSocket connection for the downloaded asset
          _subscribeToLiveTick(symbol);
        }
      }
      notifyListeners();
      print("☁️ Synced ${_ownedStocks.length} assets from Firestore.");
    } catch (e) {
      print("⚠️ Cloud sync error: $e");
    }
  }

  // 📤 UPLOAD TO CLOUD & LOCAL UI
  void addPosition(String symbol, int qty, double buyPrice) async {
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
    notifyListeners(); // Update UI instantly
    _subscribeToLiveTick(cleanSymbol); // Start socket stream

    // ☁️ Push to Firestore in the background
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('portfolio')
            .doc(cleanSymbol) // Using symbol as the document ID
            .set({
          'symbol': cleanSymbol,
          'quantity': qty,
          'averageBuyPrice': buyPrice,
          'addedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("⚠️ Failed to write $cleanSymbol to cloud: $e");
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
              _ownedStocks[targetIndex].currentLivePrice = data['current_price'].toDouble();
              notifyListeners(); // Drives instant UI state shifts
            }
          }
        },
        onError: (err) => print("❌ Portfolio Stream Error for $symbol: $err"),
        onDone: () {
           print("🔌 Portfolio Stream Closed for $symbol");
           _activeSockets.remove(symbol);
        }
      );
    } catch (e) {
      print("⚠️ Matrix WebSocket failure: $e");
    }
  }

  // 🧹 CLEANUP ON LOGOUT
  void _clearPortfolio() {
    _ownedStocks.clear();
    for (var channel in _activeSockets.values) {
      channel.sink.close();
    }
    _activeSockets.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _clearPortfolio();
    super.dispose();
  }
}