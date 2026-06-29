import 'package:flutter/foundation.dart';

// This reactive variable acts as the "eyes" for the Llama-3 AI.
// It updates silently in the background whenever the user opens a stock chart or live stream.
final ValueNotifier<String> currentBotContext = ValueNotifier<String>("home");