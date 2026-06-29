import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/stock_data.dart';
import '../services/api_service.dart';
class LiveStreamService {
  WebSocketChannel? _channel;
  Stream<StockData> connectToLiveStream(String symbol) {
    final wsUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl/ws/live/${symbol.toUpperCase()}');
    _channel = WebSocketChannel.connect(uri);
    return _channel!.stream.map((rawMessage) {
      final Map<String, dynamic> jsonData = jsonDecode(rawMessage);
      return StockData.fromJson({
        ...jsonData,
        'action': 'LIVE TICK',
        'reasoning': 'Real-time neural monitoring active.',
        'sentiment': 0.72,
        'suitability': 'N/A',
      });
    });
  }
  void disconnect() {
    _channel?.sink.close();
  }
}
