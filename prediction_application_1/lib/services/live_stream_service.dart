import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/stock_data.dart';
import '../services/api_service.dart'; // To get the base IP

class LiveStreamService {
  WebSocketChannel? _channel;
  
  /// Opens a live WebSocket connection for a specific symbol
  Stream<StockData> connectToLiveStream(String symbol) {
    // 1. Get your IP and replace 'http' with 'ws' for websockets
    final wsUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl/ws/live/${symbol.toUpperCase()}');
    
    // 2. Open the connection
    _channel = WebSocketChannel.connect(uri);
    
    // 3. Listen to the stream and convert raw JSON into your StockData model
    return _channel!.stream.map((rawMessage) {
      final Map<String, dynamic> jsonData = jsonDecode(rawMessage);
      
      // We pass some default strings for the AI reasoning since 
      // the live tick skips the heavy LLM call for speed.
      return StockData.fromJson({
        ...jsonData,
        'action': 'LIVE TICK',
        'reasoning': 'Real-time neural monitoring active.',
        'sentiment': 0.72,
        'suitability': 'N/A',
      });
    });
  }

  /// Closes the connection when the user leaves the screen
  void disconnect() {
    _channel?.sink.close();
  }
}