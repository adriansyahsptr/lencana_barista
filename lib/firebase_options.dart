import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVbpQ8hJeq108WMwKNTylRnWCKRKRpJtM',
    appId: '1:284085706539:android:4703d8c4a28d57eb84ef6e',
    messagingSenderId: '284085706539',
    projectId: 'lencana-barista',
    storageBucket: 'lencana-barista.appspot.com',
  );
}
