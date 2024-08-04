package com.example.lencana_barista

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.google.firebase.FirebaseApp

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FirebaseApp.initializeApp(this)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
