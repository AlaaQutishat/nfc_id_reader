package com.example.nfc_id_reader

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.security.Security

/** NfcIdReaderPlugin */
class NfcIdReaderPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, NfcAdapter.ReaderCallback {

    companion object {
        private const val TAG = "NfcIdReaderPlugin"
    }

    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private var resultCallback: Result? = null

    // Guard flag: tracks whether reader mode is currently registered so we
    // never call enableReaderMode twice without a matching disable in between.
    @Volatile private var readerModeEnabled = false

    // Native NFC scanning dialog (shown while waiting for / reading the card)
    private var nfcScanDialog: NfcScanDialog? = null

    // Scan parameters
    private var docNumber: String? = null
    private var dateOfBirth: String? = null  // YYMMDD
    private var expiryDate: String? = null   // YYMMDD
    private var canNumber: String? = null

    // ──────────────────────────────────────────────────────────────────────────
    // FlutterPlugin
    // ──────────────────────────────────────────────────────────────────────────

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "nfc_id_reader")
        channel.setMethodCallHandler(this)

        try {
            Security.removeProvider("BC")
            Security.insertProviderAt(BouncyCastleProvider(), 1)
        } catch (e: Exception) {
            Log.w(TAG, "BouncyCastle setup error: ${e.message}")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MethodCallHandler
    // ──────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")

            "startScanning" -> {
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "Plugin not attached to an activity", null)
                    return
                }

                // Cancel any pending result from a previous scan attempt
                resultCallback?.error("CANCELLED", "New scan started", null)
                resultCallback = result

                docNumber = call.argument("docNumber")
                dateOfBirth = call.argument("dob")
                expiryDate = call.argument("expiry")
                canNumber = call.argument("can")

                // Show the NFC scanning dialog
                nfcScanDialog?.dismissNow()
                nfcScanDialog = NfcScanDialog(act).also { dlg ->
                    dlg.show {
                        // User pressed Cancel inside the dialog
                        resultCallback?.error("CANCELLED", "Scan cancelled by user", null)
                        resultCallback = null
                        CoroutineScope(Dispatchers.IO).launch { safeDisableReaderMode() }
                    }
                }

                // Run the Binder IPC off the main thread to avoid ANR.
                CoroutineScope(Dispatchers.IO).launch {
                    safeEnableReaderMode()
                }
            }

            "stopScanning" -> {
                resultCallback?.error("CANCELLED", "Scan cancelled by user", null)
                resultCallback = null
                nfcScanDialog?.dismissNow()
                nfcScanDialog = null
                CoroutineScope(Dispatchers.IO).launch {
                    safeDisableReaderMode()
                }
                result.success("Stopped")
            }

            else -> result.notImplemented()
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // ActivityAware
    // ──────────────────────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        safeDisableReaderMode()
        activity = null
        nfcAdapter = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
    }

    override fun onDetachedFromActivity() {
        safeDisableReaderMode()
        activity = null
        nfcAdapter = null
    }

    // ──────────────────────────────────────────────────────────────────────────
    // NFC helpers — call from any thread
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Always disables first, then re-enables reader mode.
     * This ensures the NFC adapter is in a clean state even on a second scan.
     */
    private fun safeEnableReaderMode() {
        val act = activity ?: return

        // Always re-fetch the adapter — after an NFC service crash and restart
        // (common on MIUI/Xiaomi) the old Binder is dead and we need a fresh one.
        val freshAdapter = NfcAdapter.getDefaultAdapter(act)
        if (freshAdapter == null) {
            Log.e(TAG, "NFC not available on this device")
            mainHandler.post {
                resultCallback?.error("NFC_ERROR", "NFC is not available", null)
                resultCallback = null
            }
            return
        }
        nfcAdapter = freshAdapter

        // Pre-disable to guarantee a clean state, even if the flag says we're
        // already disabled — the service may have restarted without our knowledge.
        try {
            freshAdapter.disableReaderMode(act)
        } catch (e: Exception) {
            // Service may have just restarted — wait briefly before enabling.
            Log.w(TAG, "disableReaderMode (pre-enable) failed: ${e.message} — waiting 500 ms")
            Thread.sleep(500)
        }
        readerModeEnabled = false

        try {
            val options = Bundle().apply {
                putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 1000)
            }
            freshAdapter.enableReaderMode(
                act,
                this,
                NfcAdapter.FLAG_READER_NFC_A or
                        NfcAdapter.FLAG_READER_NFC_B or
                        NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
                options
            )
            readerModeEnabled = true
            Log.d(TAG, "NFC reader mode enabled")
        } catch (e: Exception) {
            Log.e(TAG, "enableReaderMode failed: ${e.message}")
            readerModeEnabled = false
            mainHandler.post {
                resultCallback?.error("NFC_ERROR", "Could not enable NFC reader: ${e.message}", null)
                resultCallback = null
            }
        }
    }

    private fun safeDisableReaderMode() {
        val act = activity ?: run { readerModeEnabled = false; return }
        // Re-fetch the adapter in case the service restarted since last use.
        val adapter = NfcAdapter.getDefaultAdapter(act) ?: run {
            readerModeEnabled = false
            return
        }
        nfcAdapter = adapter
        try {
            adapter.disableReaderMode(act)
            Log.d(TAG, "NFC reader mode disabled")
        } catch (e: Exception) {
            Log.w(TAG, "disableReaderMode failed: ${e.message}")
        } finally {
            readerModeEnabled = false
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // NfcAdapter.ReaderCallback
    // ──────────────────────────────────────────────────────────────────────────

    override fun onTagDiscovered(tag: Tag?) {
        tag ?: return

        // Step 1 → AUTH: card detected, starting authentication
        nfcScanDialog?.updateState(NfcScanDialog.State.AUTH)

        CoroutineScope(Dispatchers.IO).launch {
            // Step 2 → READING: after a short pause to let BAC/PACE finish
            kotlinx.coroutines.delay(1200)
            withContext(Dispatchers.Main) {
                nfcScanDialog?.updateState(NfcScanDialog.State.READING)
            }

            try {
                val reader = PassportReader(tag)
                val data = reader.readPassport(docNumber, dateOfBirth, expiryDate, canNumber)

                withContext(Dispatchers.Main) {
                    // Step 3 → SUCCESS / Completed
                    nfcScanDialog?.updateState(NfcScanDialog.State.SUCCESS)
                    nfcScanDialog?.dismiss()
                    nfcScanDialog = null
                    resultCallback?.success(data)
                    resultCallback = null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Passport read error: ${e.message}")
                withContext(Dispatchers.Main) {
                    nfcScanDialog?.updateState(NfcScanDialog.State.ERROR, e.message)
                    nfcScanDialog?.dismiss()
                    nfcScanDialog = null
                    resultCallback?.error("SCAN_ERROR", e.message, null)
                    resultCallback = null
                }
            } finally {
                safeDisableReaderMode()
            }
        }
    }
}
