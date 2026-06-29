import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }
  Future<void> showProfitAlert({
    required String symbol,
    required double profitPercent,
    required double currentPrice,
    required double buyPrice,
  }) async {
    if (!_initialized) await init();
    final androidDetails = AndroidNotificationDetails(
      'profit_alerts',
      'Profit Alerts',
      channelDescription: 'Notifications when your stocks reach maximum profit',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF00FFA3),
      enableVibration: true,
      playSound: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      symbol.hashCode,
      '$symbol +${profitPercent.toStringAsFixed(1)}% Profit!',
      'Price hit Rs.${currentPrice.toStringAsFixed(2)} (bought at Rs.${buyPrice.toStringAsFixed(2)}). Consider booking profits!',
      details,
    );
  }
  Future<void> showTargetReachedAlert({
    required String symbol,
    required double currentPrice,
    required double targetPrice,
  }) async {
    if (!_initialized) await init();
    final androidDetails = AndroidNotificationDetails(
      'target_alerts',
      'Target Price Alerts',
      channelDescription: 'Notifications when stock hits your target price',
      importance: Importance.max,
      priority: Priority.max,
      color: const Color(0xFF00FFA3),
      enableVibration: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      (symbol.hashCode + 1000),
      '$symbol Target Reached!',
      'Price Rs.${currentPrice.toStringAsFixed(2)} hit target Rs.${targetPrice.toStringAsFixed(2)}. Time to sell!',
      details,
    );
  }
  Future<void> showStopLossAlert({
    required String symbol,
    required double currentPrice,
    required double stopLoss,
  }) async {
    if (!_initialized) await init();
    final androidDetails = AndroidNotificationDetails(
      'stoploss_alerts',
      'Stop Loss Alerts',
      channelDescription: 'Notifications when stock hits stop loss',
      importance: Importance.max,
      priority: Priority.max,
      color: const Color(0xFFFF5252),
      enableVibration: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      (symbol.hashCode + 2000),
      '$symbol Stop Loss Hit!',
      'Price dropped to Rs.${currentPrice.toStringAsFixed(2)}. Stop loss was Rs.${stopLoss.toStringAsFixed(2)}. Exit to limit losses.',
      details,
    );
  }
}
