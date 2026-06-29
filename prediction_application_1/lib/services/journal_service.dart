import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
class JournalService {
  static const String _key = "trade_logs";
  Future<void> saveTrade(Map<String, dynamic> trade) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_key) ?? [];
    logs.add(jsonEncode(trade));
    await prefs.setStringList(_key, logs);
  }
  Future<List<Map<String, dynamic>>> getTrades() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_key) ?? [];
    return logs.map((item) => jsonDecode(item) as Map<String, dynamic>).toList().reversed.toList();
  }
  Future<void> clearJournal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
