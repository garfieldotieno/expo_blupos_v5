package com.blupos.blupos_wallet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsChannelHandler: SmsChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize SMS channel handler
        smsChannelHandler = SmsChannelHandler(this, flutterEngine)
    }

    override fun onDestroy() {
        super.onDestroy()
        smsChannelHandler?.dispose()
    }
}
