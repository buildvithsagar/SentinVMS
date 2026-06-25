package com.vms.app

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SecureStoragePlugin : FlutterPlugin, MethodCallHandler {
    private var encryptedPrefs: SharedPreferences? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        initializePreferences(binding.applicationContext, binding)
    }

    private fun initializePreferences(context: Context, binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            encryptedPrefs = EncryptedSharedPreferences.create(
                context,
                "vms_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            val channel = MethodChannel(binding.binaryMessenger, "com.vms.app/secure_storage")
            channel.setMethodCallHandler(this)
        } catch (e: Exception) {
            // Android Keystore can occasionally become corrupted. Recreate preferences on failure.
            try {
                context.deleteSharedPreferences("vms_secure_prefs")
                val masterKey = MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

                encryptedPrefs = EncryptedSharedPreferences.create(
                    context,
                    "vms_secure_prefs",
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                )

                val channel = MethodChannel(binding.binaryMessenger, "com.vms.app/secure_storage")
                channel.setMethodCallHandler(this)
            } catch (ex: Exception) {
                // Keystore exception could not be recovered
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onMethodCall(call: MethodCall, result: Result) {
        val prefs = encryptedPrefs
        if (prefs == null) {
            result.error("INITIALIZATION_FAILED", "EncryptedSharedPreferences not initialized", null)
            return
        }

        when (call.method) {
            "write" -> {
                val key = call.argument<String>("key") ?: return result.error("INVALID", "key required", null)
                val value = call.argument<String>("value") ?: return result.error("INVALID", "value required", null)
                prefs.edit().putString(key, value).apply()
                result.success(null)
            }
            "read" -> {
                val key = call.argument<String>("key") ?: return result.error("INVALID", "key required", null)
                result.success(prefs.getString(key, null))
            }
            "delete" -> {
                val key = call.argument<String>("key") ?: return result.error("INVALID", "key required", null)
                prefs.edit().remove(key).apply()
                result.success(null)
            }
            "clear" -> {
                prefs.edit().clear().apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
