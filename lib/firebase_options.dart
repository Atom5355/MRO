import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB7yp5mC91Xn0fBONo5V6t3Ridkus7FlLs',
    authDomain: 'mroengine-6b759.firebaseapp.com',
    projectId: 'mroengine-6b759',
    storageBucket: 'mroengine-6b759.firebasestorage.app',
    messagingSenderId: '1026126964845',
    appId: '1:1026126964845:web:b8769831e1331fc320f764',
  );

  static FirebaseOptions get currentPlatform => web;
}
