import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class StockChart extends StatelessWidget {
  // Fixed: Using CandleModel instead of the old PredictedCandle
  final List<CandleModel> historyData;
  final double? aiTargetPrice;

  const StockChart({
    super.key, 
    required this.historyData, 
    this.aiTargetPrice
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. The Main Roadmap Chart (History Bars)
          if (historyData.isEmpty)
            const Center(child: Text("No Data Available", style: TextStyle(color: Colors.grey)))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: historyData.map((candle) {
                return _buildCandleStick(candle);
              }).toList(),
            ),

          // 2. The AI DNA Target Line
          if (aiTargetPrice != null && historyData.isNotEmpty)
            Positioned(
              top: 50, 
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    height: 1.5,
                    width: double.infinity,
                    color: Colors.blueAccent.withOpacity(0.8),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "AI TARGET: ₹${aiTargetPrice!.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCandleStick(CandleModel candle) {
    // Fixed: open/close logic for color
    bool isBullish = candle.close >= candle.open;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 8,
          // Fixed: Simplified height scaling for UI
          height: (candle.close / 100).clamp(10.0, 150.0), 
          decoration: BoxDecoration(
            color: isBullish ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        // Fixed: Extracting time from DateTime
        Text(
          "${candle.time.hour}:${candle.time.minute}", 
          style: const TextStyle(fontSize: 8, color: Colors.grey)
        ),
      ],
    );
  }
}