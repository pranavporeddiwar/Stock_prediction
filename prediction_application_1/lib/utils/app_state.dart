import 'package:flutter/foundation.dart';

// This holds the background context for the AI.
// It can be accessed and updated from anywhere in the app.
final ValueNotifier<String> currentBotContext = ValueNotifier<String>(
  "User is looking at the main Watchlist."
);