package com.blupos.blupos_wallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsChannelHandler(private val context: Context, flutterEngine: FlutterEngine) {
    private val TAG = "SmsChannelHandler"
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.blupos.wallet/sms")

    private val smsBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                "com.blupos.wallet.SMS_RECEIVED" -> {
                    // Any incoming SMS for blinking animation
                    val smsData = intent.getSerializableExtra("sms_data") as? Map<String, Any>
                    if (smsData != null) {
                        Log.d(TAG, "Received SMS broadcast: $smsData")
                        channel.invokeMethod("onSmsReceived", smsData)
                    }
                }
                "com.blupos.wallet.SMS_PAYMENT_RECEIVED" -> {
                    // Parsed payment SMS
                    val paymentData = intent.getSerializableExtra("payment_data") as? Map<String, Any>
                    if (paymentData != null) {
                        Log.d(TAG, "Received payment broadcast: $paymentData")
                        channel.invokeMethod("onPaymentReceived", paymentData)
                        
                        // ✅ CRITICAL: Trigger Dart reconciliation workflow
                        // Note: This would need to be implemented as a platform channel method
                        // that calls back to the Dart SMSReconciliationService
                        // For now, the Dart side handles this in _handleIncomingPayment
                    }
                }
            }
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startSmsMonitoring" -> {
                    startSmsMonitoring()
                    result.success(true)
                }
                "stopSmsMonitoring" -> {
                    stopSmsMonitoring()
                    result.success(true)
                }
                "getSmsPermissions" -> {
                    // Permissions are handled in Flutter, just confirm
                    result.success(true)
                }
                "loadSmsInbox" -> {
                    loadSmsInbox(result)
                }
                else -> result.notImplemented()
            }
        }

        // Register broadcast receiver for SMS messages and payments
        val filter = IntentFilter().apply {
            addAction("com.blupos.wallet.SMS_RECEIVED")
            addAction("com.blupos.wallet.SMS_PAYMENT_RECEIVED")
        }
        context.registerReceiver(smsBroadcastReceiver, filter)
    }

    private fun startSmsMonitoring() {
        Log.d(TAG, "SMS monitoring started")
        // SMS monitoring is handled by the SmsReceiver in AndroidManifest
        // This method can be used for additional setup if needed
    }

    private fun stopSmsMonitoring() {
        Log.d(TAG, "SMS monitoring stopped")
        // SMS monitoring is handled by the SmsReceiver in AndroidManifest
        // This method can be used for cleanup if needed
    }

    private fun loadSmsInbox(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Loading SMS inbox with real-time data...")

            val smsList = mutableListOf<Map<String, Any>>()

            // Query SMS inbox for ALL unread messages (remove 24-hour restriction for real-time data)
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("_id", "address", "body", "date", "read", "type", "thread_id")
            val selection = "read = 0"  // Only unread messages, no time restriction
            val selectionArgs = null

            val cursor: Cursor? = context.contentResolver.query(uri, projection, selection, selectionArgs, "date DESC")

            cursor?.use {
                val idColumn = it.getColumnIndex("_id")
                val addressColumn = it.getColumnIndex("address")
                val bodyColumn = it.getColumnIndex("body")
                val dateColumn = it.getColumnIndex("date")
                val readColumn = it.getColumnIndex("read")
                val typeColumn = it.getColumnIndex("type")
                val threadIdColumn = it.getColumnIndex("thread_id")

                var validSmsCount = 0
                var filteredSmsCount = 0

                while (it.moveToNext()) {
                    val id = it.getLong(idColumn)
                    val address = it.getString(addressColumn) ?: ""
                    val body = it.getString(bodyColumn) ?: ""
                    val date = it.getLong(dateColumn)
                    val read = it.getInt(readColumn)
                    val type = it.getInt(typeColumn)
                    val threadId = it.getLong(threadIdColumn)

                    // Filter out system/technical messages and empty messages
                    val isValidSms = isValidUserSms(address, body, type)

                    Log.d(TAG, "SMS Entry: ID=$id, Address=$address, Read=$read, Type=$type, Body='${body.take(50)}...', Valid=$isValidSms")

                    if (read == 0 && isValidSms) {
                        val smsData = mapOf<String, Any>(
                            "id" to id.toString(),
                            "sender" to address,
                            "message" to body,
                            "timestamp" to date,
                            "read" to false
                        )
                        smsList.add(smsData)
                        validSmsCount++
                    } else if (read == 0) {
                        filteredSmsCount++
                        Log.d(TAG, "Filtered out SMS: Address=$address, Type=$type, Body='${body.take(30)}...'")
                    }
                }

                Log.d(TAG, "SMS Query Results: Total unread=${it.count}, Valid user SMS=$validSmsCount, Filtered out=$filteredSmsCount")
            }

            Log.d(TAG, "Returning ${smsList.size} valid unread SMS to Flutter")
            result.success(smsList)

        } catch (e: Exception) {
            Log.e(TAG, "Error loading SMS inbox", e)
            result.error("SMS_LOAD_ERROR", "Failed to load SMS inbox: ${e.message}", null)
        }
    }

    /**
     * Filters out system messages and ensures we only count valid user SMS
     */
    private fun isValidUserSms(address: String, body: String, type: Int): Boolean {
        // Filter criteria for valid user SMS:

        // 1. Must have a sender address
        if (address.isBlank()) {
            return false
        }

        // 2. Must have message body
        if (body.isBlank()) {
            return false
        }

        // 3. SMS type should be 1 (received) - filter out sent messages, drafts, etc.
        if (type != 1) {  // 1 = received SMS
            return false
        }

        // 4. Filter out obvious system/technical senders
        val systemSenders = listOf(
            "android", "system", "verizon", "att", "tmobile", "sprint",
            "vodafone", "airtel", "safaricom", "orange", "tigo", "mtn"
        ).map { it.lowercase() }

        if (systemSenders.any { address.lowercase().contains(it) }) {
            return false
        }

        // 5. Filter out messages that look like system notifications
        val systemKeywords = listOf(
            "android", "system", "notification", "update", "download",
            "install", "battery", "storage", "memory", "network"
        ).map { it.lowercase() }

        if (systemKeywords.any { body.lowercase().contains(it) }) {
            return false
        }

        // 6. Must be reasonable length (filter out corrupted entries)
        if (body.length < 2 || body.length > 1000) {
            return false
        }

        return true
    }

    fun dispose() {
        try {
            context.unregisterReceiver(smsBroadcastReceiver)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Broadcast receiver not registered")
        }
    }
}
