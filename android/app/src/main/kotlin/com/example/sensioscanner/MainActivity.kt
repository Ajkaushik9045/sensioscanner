package com.example.sensioscanner

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sensioscanner/bluetooth"
    private var pendingResult: MethodChannel.Result? = null
    private val REQUEST_ENABLE_BT = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enableBluetooth") {
                val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                if (bluetoothAdapter == null) {
                    result.error("UNAVAILABLE", "Bluetooth not supported on this device", null)
                } else if (bluetoothAdapter.isEnabled) {
                    result.success(true)
                } else {
                    pendingResult = result
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    try {
                        startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                        pendingResult = null
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_BT) {
            if (resultCode == RESULT_OK) {
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }
}
