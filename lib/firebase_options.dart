// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
//
// IMPORTANTE: substitua este arquivo pelo gerado em:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Os valores abaixo são um modelo; o app só receberá push do MESMO projeto Firebase
// configurado no servidor (conta de serviço em FIREBASE_CREDENTIALS / Laravel).

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
      default:
        throw UnsupportedError(
          'Firebase não configurado para esta plataforma.',
        );
    }
  }

  // Alinhado a android/app/google-services.json (projeto rdopro-5f38f).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlG0IqH80PqITmaiiiDKuYir2tCEndAT8',
    appId: '1:474413163033:android:ea8e9384a8b8d21dc60088',
    messagingSenderId: '474413163033',
    projectId: 'rdopro-5f38f',
    storageBucket: 'rdopro-5f38f.firebasestorage.app',
  );

  /// Alinhado a ios/Runner/GoogleService-Info.plist.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBK1PAkzBmw0ihm4Y_KlaTRlrsBXLkYaLw',
    appId: '1:474413163033:ios:0ebd447982bc175dc60088',
    messagingSenderId: '474413163033',
    projectId: 'rdopro-5f38f',
    storageBucket: 'rdopro-5f38f.firebasestorage.app',
    iosBundleId: 'com.asaoperacoes.rdopro',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'CONFIGURE_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '474413163033',
    projectId: 'rdopro-5f38f',
    authDomain: 'rdopro-5f38f.firebaseapp.com',
    storageBucket: 'rdopro-5f38f.firebasestorage.app',
  );
}
