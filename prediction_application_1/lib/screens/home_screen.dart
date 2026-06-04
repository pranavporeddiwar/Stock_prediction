import 'package:flutter/material.dart';
import 'stock_prediction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController(text: "TCS");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_graph_rounded, color: Color(0xFF00FFA3), size: 100),
              const SizedBox(height: 20),
              const Text("AI STOCK ANALYST", 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 60),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: "ENTER NSE SYMBOL",
                  hintStyle: const TextStyle(color: Colors.white12, fontSize: 12),
                  filled: true, fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.white10)),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockPredictionScreen(symbol: _controller.text))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFA3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text("ANALYZE NOW", 
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}