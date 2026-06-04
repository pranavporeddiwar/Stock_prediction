import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/app_state.dart'; // Imports the context state

class GlobalChatBot extends StatefulWidget {
  final Widget child;
  const GlobalChatBot({super.key, required this.child});

  @override
  State<GlobalChatBot> createState() => _GlobalChatBotState();
}

class _GlobalChatBotState extends State<GlobalChatBot> {
  bool _isOpen = false;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "bot", "text": "Hi! I'm Neural Tutor. Need help understanding the AI signals or a trading term?"}
  ];
  bool _isTyping = false;

  // IMPORTANT: Make sure this is your laptop's current IPv4 address!
  final String baseUrl = "http://192.168.1.78:8000";

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userText = _controller.text.trim();
    setState(() {
      _messages.add({"role": "user", "text": userText});
      _controller.clear();
      _isTyping = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        // Sends the user's message PLUS the background context
        body: json.encode({
          "message": userText,
          "context": currentBotContext.value 
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({"role": "bot", "text": data["reply"]});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "Network error. Make sure you are connected to the server."});
      });
    } finally {
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Wrap everything in a transparent Material widget for root-level overlays
    return Material(
      type: MaterialType.transparency, 
      child: Stack(
        children: [
          // 2. Main App Background (Watchlist, Prediction Screen, etc.)
          widget.child,

          // 3. SafeArea ensures the UI doesn't hide under the Motorola bottom nav bar
          SafeArea(
            child: Stack(
              children: [
                // Chat Window Overlay
                if (_isOpen)
                  Positioned(
                    bottom: 80, // Moved higher to stay above the button
                    right: 20,
                    left: 20,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.5, // Responsive height
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00FFA3).withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FFA3),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("NEURAL TUTOR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                                GestureDetector(onTap: () => setState(() => _isOpen = false), child: const Icon(Icons.close, color: Colors.black, size: 20)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(15),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                bool isBot = _messages[index]["role"] == "bot";
                                return Align(
                                  alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                                    decoration: BoxDecoration(
                                      color: isBot ? Colors.white10 : const Color(0xFF00FFA3).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(_messages[index]["text"]!, style: TextStyle(color: isBot ? Colors.white : const Color(0xFF00FFA3), fontSize: 12)),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_isTyping)
                            const Padding(padding: EdgeInsets.all(8.0), child: Text("Tutor is typing...", style: TextStyle(color: Colors.white54, fontSize: 10))),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Material( // 4. Required to make TextField tappable in an overlay
                                    color: Colors.transparent,
                                    child: TextField(
                                      controller: _controller,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: "Ask about a trading concept...",
                                        hintStyle: const TextStyle(color: Colors.white38),
                                        filled: true,
                                        fillColor: Colors.white10,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF00FFA3),
                                  child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 18), onPressed: _sendMessage),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                // Floating Action Button Overlay
                Positioned(
                  bottom: 15, // Anchored safely above the nav bar
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFF00FFA3),
                    onPressed: () => setState(() => _isOpen = !_isOpen),
                    child: Icon(_isOpen ? Icons.keyboard_arrow_down : Icons.smart_toy, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}