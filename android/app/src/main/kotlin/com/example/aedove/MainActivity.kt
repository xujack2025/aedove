package com.app.aedove

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge for backward compatibility with Android 15+
        // This ensures proper handling of system bars without deprecated color APIs
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(MediaStorePlugin())
        acquireMulticastLock()
    }

    private fun acquireMulticastLock() {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("aedove_multicast")
            multicastLock?.setReferenceCounted(false)
            multicastLock?.acquire()
            android.util.Log.d("Aedove", "Multicast lock acquired")

            // Acquire partial wake lock to keep CPU awake for network operations
            val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "aedove::NetworkWakeLock"
            )
            wakeLock?.acquire(10*60*1000L /*10 minutes*/)
            android.util.Log.d("Aedove", "Wake lock acquired")
        } catch (e: Exception) {
            android.util.Log.e("Aedove", "Error acquiring locks: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            multicastLock?.release()
            wakeLock?.release()
            android.util.Log.d("Aedove", "Locks released")
        } catch (e: Exception) {
            android.util.Log.e("Aedove", "Error releasing locks: ${e.message}")
        }
    }
}
