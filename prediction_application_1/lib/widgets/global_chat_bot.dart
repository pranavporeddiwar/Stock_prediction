import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/app_state.dart';
import '../models/stock_data.dart';

class GlobalChatBot extends StatefulWidget {
  final StockData? stockData;

  const GlobalChatBot({super.key, this.stockData});

  /// Slide up the chat interface from anywhere — now with optional StockData for deep prediction context!
  static void show(BuildContext context, {StockData? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlobalChatBot(stockData: data),
    );
  }

  @override
  State<GlobalChatBot> createState() => _GlobalChatBotState();
}

class _GlobalChatBotState extends State<GlobalChatBot> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = true;

  // Storage key is scoped per-stock for relevant conversation threads
  String get _storageKey {
    final symbol = widget.stockData?.symbol ?? 'general';
    return 'chat_history_${symbol.toUpperCase()}';
  }

  String? get _activeSymbol => widget.stockData?.symbol.toUpperCase();

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // ==========================================
  // 💾 PERSISTENT CHAT HISTORY (SharedPreferences)
  // ==========================================
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedHistory = prefs.getString(_storageKey);

      if (savedHistory != null && savedHistory.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedHistory);
        _messages = decoded.map<Map<String, String>>((item) {
          return Map<String, String>.from(item as Map);
        }).toList();

        // Cap at 50 messages to prevent storage bloat
        if (_messages.length > 50) {
          _messages = _messages.sublist(_messages.length - 50);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Chat history load error: $e");
    }

    // Add welcome message if history is empty
    if (_messages.isEmpty) {
      String topic = _activeSymbol ?? "the broader market";
      _messages.add({
        "sender": "bot",
        "text":
            "🙏 Namaste! Neural Tutor initialized for $topic.\n\n"
            "I'm your Indian market expert. Ask me anything about:\n"
            "• Current AI prediction & signals\n"
            "• Upcoming price movement\n"
            "• Target price & stop-loss levels\n"
            "• Best buy/sell timing\n"
            "• Risk analysis & trading style\n\n"
            "All prices in ₹, all times in IST. How can I help your trading strategy today?"
      });
    }

    if (mounted) {
      setState(() => _isLoadingHistory = false);
      _scrollToBottom();
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Cap at 50 messages before saving
      final messagesToSave =
          _messages.length > 50
              ? _messages.sublist(_messages.length - 50)
              : _messages;
      await prefs.setString(_storageKey, jsonEncode(messagesToSave));
    } catch (e) {
      debugPrint("⚠️ Chat history save error: $e");
    }
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear Chat History", style: TextStyle(color: Colors.white)),
        content: Text(
          "This will delete all messages for ${_activeSymbol ?? 'general chat'}. This cannot be undone.",
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear", style: TextStyle(color: Color(0xFFF34141))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      setState(() {
        _messages.clear();
        String topic = _activeSymbol ?? "the broader market";
        _messages.add({
          "sender": "bot",
          "text": "🙏 Chat cleared! Neural Tutor reinitialized for $topic. How can I assist you?"
        });
      });
      _saveChatHistory();
    }
  }

  // ==========================================
  // 📊 PREDICTION DATA SERIALIZER
  // ==========================================
  Map<String, dynamic>? _buildPredictionPayload() {
    if (widget.stockData == null) return null;

    final d = widget.stockData!;
    return {
      "symbol": d.symbol,
      "current_price": d.currentPrice,
      "target_price": d.targetPrice,
      "stop_loss": d.stopLoss,
      "action": d.action,
      "rsi": d.rsi,
      "risk_level": d.riskLevel,
      "trading_style": d.tradingStyle,
      "style_reason": d.styleReason,
      "sentiment": d.sentiment,
      "reasoning": d.reasoning,
      "buy_time": d.buyTime,
      "sell_time": d.sellTime,
      "forecast": d.predictedPath.map((candle) {
        return {
          "close": candle.close,
          "pattern": candle.pattern ?? "Standard",
          "risk": candle.risk ?? "Low risk",
        };
      }).toList(),
    };
  }

  // ==========================================
  // 📨 SEND MESSAGE WITH FULL CONTEXT
  // ==========================================
  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    String userMsg = _controller.text.trim();

    setState(() {
      _messages.add({"sender": "user", "text": userMsg});
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();
    _saveChatHistory(); // Persist the user message immediately

    try {
      // ⚡ Send message with full conversation history + prediction data
      String reply = await ApiService().sendChatMessage(
        userMsg,
        currentBotContext.value,
        history: _messages,
        predictionData: _buildPredictionPayload(),
      );

      if (mounted) {
        setState(() {
          _messages.add({"sender": "bot", "text": reply});
          _isTyping = false;
        });
        _saveChatHistory(); // Persist the bot response
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text": "⚠️ Connection error: Unable to reach neural network. Please try again."
          });
          _isTyping = false;
        });
        _saveChatHistory();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF9D4EDD), width: 1.5)),
      ),
      child: Column(
        children: [
          // ═══════════════════════
          // HEADER: Drag Handle, Title, Context Chip, Clear Button
          // ═══════════════════════
          _buildHeader(),

          // ═══════════════════════
          // CHAT MESSAGES
          // ═══════════════════════
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF9D4EDD),
                          strokeWidth: 2,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Loading chat history...",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      bool isUser = _messages[index]["sender"] == "user";
                      return _buildMessageBubble(
                        _messages[index]["text"]!,
                        isUser,
                      );
                    },
                  ),
          ),

          // ═══════════════════════
          // TYPING INDICATOR
          // ═══════════════════════
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Color(0xFF9D4EDD),
                        strokeWidth: 1.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Neural engine is synthesizing...",
                      style: TextStyle(
                        color: Color(0xFF9D4EDD),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ═══════════════════════
          // QUICK ACTION CHIPS (when viewing a prediction)
          // ═══════════════════════
          if (widget.stockData != null) _buildQuickActions(),

          // ═══════════════════════
          // INPUT BOX
          // ═══════════════════════
          _buildInputBox(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF9D4EDD),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Neural Tutor",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
              // Stock context chip
              if (_activeSymbol != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D372).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF22D372).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.show_chart,
                        color: Color(0xFF22D372),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _activeSymbol!,
                        style: const TextStyle(
                          color: Color(0xFF22D372),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              // Clear history button
              GestureDetector(
                onTap: _clearChatHistory,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white38,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, top: 4),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFF9D4EDD).withOpacity(0.6),
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "NEURAL TUTOR",
                      style: TextStyle(
                        color: const Color(0xFF9D4EDD).withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            SelectableText(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final List<Map<String, String>> quickQuestions = [
      {"label": "📈 Upcoming?", "question": "What could be the upcoming price prediction based on current movement?"},
      {"label": "🎯 Target?", "question": "What is the exact target price and stop-loss for this stock?"},
      {"label": "⏰ When to buy?", "question": "When is the best time to buy and sell today?"},
      {"label": "⚡ Risk?", "question": "What is the current risk level and how should I manage it?"},
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: quickQuestions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _controller.text = quickQuestions[index]["question"]!;
              _sendMessage();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF9D4EDD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9D4EDD).withOpacity(0.25),
                ),
              ),
              child: Text(
                quickQuestions[index]["label"]!,
                style: const TextStyle(
                  color: Color(0xFF9D4EDD),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBox() {
    return Container(
      padding: EdgeInsets.only(
        left: 15,
        right: 15,
        bottom: MediaQuery.of(context).viewInsets.bottom + 15,
        top: 10,
      ),
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
                hintText: _activeSymbol != null
                    ? "Ask about $_activeSymbol prediction..."
                    : "Ask about the current chart...",
                hintStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF00FFA3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}