import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_state.dart';

class GlobalChatBot extends StatefulWidget {
  const GlobalChatBot({super.key});

  /// A helper function to easily slide this chat interface up from anywhere in the app!
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GlobalChatBot(),
    );
  }

  @override
  State<GlobalChatBot> createState() => _GlobalChatBotState();
}

class _GlobalChatBotState extends State<GlobalChatBot> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // The bot introduces itself dynamically based on the current reactive context!
    String topic = currentBotContext.value.contains("prediction screen for")
        ? currentBotContext.value.split("prediction screen for ")[1].split(".")[0]
        : "the broader market";
        
    _messages.add({
      "sender": "bot",
      "text": "Neural Tutor initialized. I am actively monitoring $topic. How can I assist your trading strategy today?"
    });
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    String userMsg = _controller.text.trim();
    
    setState(() {
      _messages.add({"sender": "user", "text": userMsg});
      _isTyping = true;
    });
    
    _controller.clear();

    try {
      // ⚡ MAGIC HAPPENS HERE: We send the message AND the live context!
      String reply = await ApiService().sendChatMessage(userMsg, currentBotContext.value);
      
      if (mounted) {
        setState(() {
          _messages.add({"sender": "bot", "text": reply});
          _isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({"sender": "bot", "text": "⚠️ Connection error: Unable to reach neural network."});
          _isTyping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Takes up 75% of the screen
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF9D4EDD), width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag Handle & Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF9D4EDD), size: 18),
                    SizedBox(width: 8),
                    Text("Llama-3 Neural Tutor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
          
          // Chat Bubbles
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]["sender"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12, top: 4),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF7B2CBF) : const Color(0xFF151515),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 20),
                      ),
                      border: isUser ? null : Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      _messages[index]["text"]!,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Typing Indicator
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Neural engine is synthesizing...", style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ),
            
          // Input Box
          Container(
            padding: EdgeInsets.only(left: 15, right: 15, bottom: MediaQuery.of(context).viewInsets.bottom + 15, top: 10),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ask about the current chart...",
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(color: Color(0xFF00FFA3), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}