package com.blupos.blupos_wallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.database.Cursor
import android.telephony.SmsMessage
import android.util.Log
import java.io.Serializable

data class PaymentData(
    val amount: Double,
    val reference: String,
    val sender: String?,
    val message: String,
    val timestamp: Long
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "amount" to amount,
            "reference" to reference,
            "sender" to sender,
            "message" to message,
            "timestamp" to timestamp
        )
    }
}

class SmsReceiver : BroadcastReceiver() {
    private val TAG = "SmsReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle = intent.extras
            if (bundle != null) {
                val pdus = bundle.get("pdus") as Array<*>?
                if (pdus != null) {
                    for (pdu in pdus) {
                        val smsMessage = SmsMessage.createFromPdu(pdu as ByteArray)
                        val sender = smsMessage.originatingAddress
                        val message = smsMessage.messageBody
                        val timestamp = smsMessage.timestampMillis

                        Log.d(TAG, "Received SMS from $sender: $message")

                        // Send every SMS to Flutter for blinking animation
                        sendSmsToFlutter(context, sender, message, timestamp)

                        // Parse payment message (only if it matches payment patterns)
                        if (isPaymentMessage(message)) {
                            val paymentData = parsePaymentMessage(message, sender)

                            // Send payment data to Flutter for processing
                            sendPaymentToFlutter(context, paymentData)
                        }
                    }
                }
            }
        }
    }

    private fun isPaymentMessage(message: String): Boolean {
        // Detect payment confirmation messages
        val paymentKeywords = listOf("confirmed", "received", "payment", "M-PESA", "sent", "transaction")
        return paymentKeywords.any { message.contains(it, ignoreCase = true) }
    }

    private fun parsePaymentMessage(message: String, sender: String?): PaymentData {
        // Extract amount, reference, sender for different message formats

        // Pattern 1: YL4ZEC9B6Y~Payment Of Kshs 150.00... (Reference at start)
        val refAtStartPattern = Regex("""^([A-Z0-9]+)~""")
        val kshsAmountPattern = Regex("""Kshs\s*([\d,]+\.?\d{0,2})""")

        // Pattern 2: Dear Jeffithah, Your merchant account... KES 50.00 ref #TLQ4G2B2YR
        val kesAmountPattern = Regex("""KES\s*([\d,]+\.?\d{0,2})""")
        val refPattern = Regex("""ref\s*#?(\w+)""")

        // Try different patterns based on message content
        var amount = 0.0
        var reference = ""

        // Check for Kshs format first (Jaystar Investments)
        val kshsMatch = kshsAmountPattern.find(message)
        if (kshsMatch != null) {
            amount = kshsMatch.groupValues[1].replace(",", "").toDoubleOrNull() ?: 0.0
            Log.d(TAG, "Parsed Kshs amount: $amount")

            // For Kshs format, reference might be at the beginning
            val refStartMatch = refAtStartPattern.find(message)
            if (refStartMatch != null) {
                reference = refStartMatch.groupValues[1]
                Log.d(TAG, "Parsed reference from start: $reference")
            }
        } else {
            // Check for KES format (merchant account)
            val kesMatch = kesAmountPattern.find(message)
            if (kesMatch != null) {
                amount = kesMatch.groupValues[1].replace(",", "").toDoubleOrNull() ?: 0.0
                Log.d(TAG, "Parsed KES amount: $amount")

                // For KES format, reference follows "ref #"
                val refMatch = refPattern.find(message)
                if (refMatch != null) {
                    reference = refMatch.groupValues[1]
                    Log.d(TAG, "Parsed reference: $reference")
                }
            }
        }

        Log.d(TAG, "Final parsed payment data - Amount: $amount, Reference: $reference, Sender: $sender")

        return PaymentData(
            amount = amount,
            reference = reference,
            sender = sender,
            message = message,
            timestamp = System.currentTimeMillis()
        )
    }

    private fun sendSmsToFlutter(context: Context, sender: String?, message: String, timestamp: Long) {
        try {
            // Send broadcast for any incoming SMS (for blinking animation)
            val smsIntent = Intent("com.blupos.wallet.SMS_RECEIVED")
            val senderType = when {
                sender != null && isShortCode(sender) -> "Short Code"
                sender != null && !isPhoneNumber(sender) -> "SMS Sender ID"
                sender != null && isSavedContact(context, sender) -> "Saved Contact"
                sender != null -> "Not Saved Contact"
                else -> "Unknown"
            }
            
            val smsData = mapOf(
                "sender" to (sender ?: ""),
                "senderType" to senderType,
                "message" to message,
                "timestamp" to timestamp
            )
            smsIntent.putExtra("sms_data", smsData as java.util.HashMap<String, Any>)
            context.sendBroadcast(smsIntent)

            Log.d(TAG, "Sent SMS data to Flutter for blinking: $smsData")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending SMS to Flutter", e)
        }
    }

    private fun sendPaymentToFlutter(context: Context, paymentData: PaymentData) {
        try {
            // Send broadcast to notify the app about the payment
            val broadcastIntent = Intent("com.blupos.wallet.SMS_PAYMENT_RECEIVED")
            val senderType = when {
                paymentData.sender != null && !isPhoneNumber(paymentData.sender) -> "SMS Sender ID"
                paymentData.sender != null && isShortCode(paymentData.sender) -> "Short Code"
                paymentData.sender != null && isSavedContact(context, paymentData.sender) -> "Saved Contact"
                paymentData.sender != null -> "Not Saved Contact"
                else -> "Unknown"
            }
            
            val paymentDataWithSenderType = paymentData.toMap() + mapOf("senderType" to senderType)
            broadcastIntent.putExtra("payment_data", paymentDataWithSenderType as java.util.HashMap<String, Any>)
            context.sendBroadcast(broadcastIntent)

            Log.d(TAG, "Sent payment data to Flutter: $paymentDataWithSenderType")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending payment to Flutter", e)
        }
    }

    private fun isPhoneNumber(address: String): Boolean {
        // Phone numbers are 7-15 digits, often with country codes
        return address.matches(Regex("^[+]?[0-9]{7,15}$"))
    }

    private fun isShortCode(address: String): Boolean {
        // Short codes are 3-6 digits (not full phone numbers)
        // Explicitly check for our test shortcodes: 123456, 123457
        if (address == "123456" || address == "123457") {
            return true
        }
        return address.matches(Regex("^[0-9]{3,6}$")) && !isPhoneNumber(address)
    }

    private fun isSavedContact(context: Context, phoneNumber: String): Boolean {
        try {
            val uri = android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            val projection = arrayOf(
                android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            val selection = "${android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER} = ?"
            val selectionArgs = arrayOf(phoneNumber)
            
            val cursor: Cursor? = context.contentResolver.query(uri, projection, selection, selectionArgs, null)
            
            cursor?.use {
                return it.count > 0
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if contact is saved", e)
        }
        return false
    }
}
