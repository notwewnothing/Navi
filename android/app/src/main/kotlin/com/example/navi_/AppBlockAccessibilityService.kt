package com.example.navi_

import android.accessibilityservice.AccessibilityService
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Calendar

class AppBlockAccessibilityService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {
    private var overlayView: View? = null
    private var overlayPackage: String? = null
    private var currentPackage: String? = null
    private val prefs by lazy { getSharedPreferences("app_blocker", MODE_PRIVATE) }
    private val windowManager by lazy { getSystemService(WINDOW_SERVICE) as WindowManager }

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs.registerOnSharedPreferenceChangeListener(this)
        refreshOverlay()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == this.packageName) return
        currentPackage = packageName
        refreshOverlay()
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        refreshOverlay()
    }

    override fun onInterrupt() {
        removeOverlay()
    }

    override fun onDestroy() {
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        removeOverlay()
        super.onDestroy()
    }

    private fun refreshOverlay() {
        val packageName = currentPackage
        if (packageName == null) {
            removeOverlay()
            return
        }
        if (sessionBlocks(packageName)) {
            showOverlay(packageName, appLabel(packageName), "RETURN TO YOUR FOCUS SESSION")
            return
        }
        if (ruleBlocks(packageName)) {
            showOverlay(packageName, appLabel(packageName), "CLOSE THE WORLD. OPEN THE NEXT.")
            return
        }
        removeOverlay()
    }

    private fun sessionBlocks(packageName: String): Boolean {
        val enabled = prefs.getBoolean("enabled", false)
        val strictMode = prefs.getBoolean("strictMode", false)
        val onBreak = prefs.getBoolean("onBreak", false)
        if (!enabled || (!strictMode && onBreak)) return false
        val blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet()
        return blockedPackages.contains(packageName)
    }

    private fun ruleBlocks(packageName: String): Boolean {
        val rules = prefs.getStringSet("rules", emptySet()) ?: emptySet()
        if (rules.isEmpty()) return false
        val cal = Calendar.getInstance()
        val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val todayBit = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
        val yesterdayBit = (todayBit + 6) % 7
        for (rule in rules) {
            val parts = rule.split("|")
            if (parts.size != 4) continue
            val start = parts[0].toIntOrNull() ?: continue
            val end = parts[1].toIntOrNull() ?: continue
            val dayBits = parts[2].toIntOrNull() ?: continue
            val packages = parts[3].split(",")
            if (!packages.contains(packageName)) continue
            val active = if (start <= end) {
                nowMin in start until end && (dayBits shr todayBit) and 1 == 1
            } else {
                (nowMin >= start && (dayBits shr todayBit) and 1 == 1) ||
                    (nowMin < end && (dayBits shr yesterdayBit) and 1 == 1)
            }
            if (active) return true
        }
        return false
    }

    private fun showOverlay(packageName: String, label: String, subtitle: String) {
        if (overlayView != null && overlayPackage == packageName) return
        removeOverlay()
        overlayPackage = packageName
        overlayView = blockedView(label, subtitle)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }
        windowManager.addView(overlayView, params)
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        overlayView = null
        overlayPackage = null
        runCatching { windowManager.removeView(view) }
    }

    private fun blockedView(label: String, subtitle: String): View {
        val green = Color.rgb(57, 211, 83)
        val dim = Color.rgb(0, 109, 50)
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            addView(TextView(context).apply {
                text = "$label IS BLOCKED"
                textSize = 28f
                setTextColor(green)
                gravity = Gravity.CENTER
                typeface = Typeface.MONOSPACE
            })
            addView(TextView(context).apply {
                text = subtitle
                textSize = 15f
                setTextColor(dim)
                gravity = Gravity.CENTER
                typeface = Typeface.MONOSPACE
                setPadding(0, 24, 0, 36)
            })
            addView(Button(context).apply {
                text = "GO HOME"
                setTextColor(Color.BLACK)
                setBackgroundColor(green)
                typeface = Typeface.MONOSPACE
                setOnClickListener {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    removeOverlay()
                }
            })
        }
    }

    private fun appLabel(packageName: String): String {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }
}
