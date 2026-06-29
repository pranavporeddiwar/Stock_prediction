import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBt6kKnDcMqOI5k2_sPCznn_k9KJrT8Hh4',
    appId: '1:540169070603:web:3a03ce75ce4cd94e45ff0e',
    messagingSenderId: '540169070603',
    projectId: 'stockpredictionterminal',
    authDomain: 'stockpredictionterminal.firebaseapp.com',
    storageBucket: 'stockpredictionterminal.firebasestorage.app',
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3KbQzI37CUxFyKc-RZa8O4gAN4HYLmIA',
    appId: '1:540169070603:android:2a2feff823cb07d645ff0e',
    messagingSenderId: '540169070603',
    projectId: 'stockpredictionterminal',
    storageBucket: 'stockpredictionterminal.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCz-aQHpLUYrSTdI3zc8Mq_YDKVMQdIlP4',
    appId: '1:540169070603:ios:b611e4f2fe5c356745ff0e',
    messagingSenderId: '540169070603',
    projectId: 'stockpredictionterminal',
    storageBucket: 'stockpredictionterminal.firebasestorage.app',
    iosBundleId: 'com.example.predictionApplication1',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCz-aQHpLUYrSTdI3zc8Mq_YDKVMQdIlP4',
    appId: '1:540169070603:ios:b611e4f2fe5c356745ff0e',
    messagingSenderId: '540169070603',
    projectId: 'stockpredictionterminal',
    storageBucket: 'stockpredictionterminal.firebasestorage.app',
    iosBundleId: 'com.example.predictionApplication1',
  );
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBt6kKnDcMqOI5k2_sPCznn_k9KJrT8Hh4',
    appId: '1:540169070603:web:cef75f33073d62c945ff0e',
    messagingSenderId: '540169070603',
    projectId: 'stockpredictionterminal',
    authDomain: 'stockpredictionterminal.firebaseapp.com',
    storageBucket: 'stockpredictionterminal.firebasestorage.app',
  );
}
