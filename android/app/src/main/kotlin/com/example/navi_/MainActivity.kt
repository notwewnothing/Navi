package com.example.navi_

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navi/alarm_buzz").setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val requestCode = call.argument<Int>("id")
                    val alarmId = call.argument<Int>("alarmId") ?: -1
                    val at = call.argument<Number>("at")?.toLong()
                    if (requestCode == null || at == null) {
                        result.error("BAD_ARGS", "id and at are required", null)
                    } else {
                        AlarmBuzzScheduler.schedule(this, requestCode, alarmId, at)
                        result.success(null)
                    }
                }
                "cancelAllScheduled" -> {
                    AlarmBuzzScheduler.cancelAll(this)
                    result.success(null)
                }
                "start" -> {
                    AlarmBuzzService.start(this, call.argument<Int>("alarmId") ?: -1)
                    result.success(null)
                }
                "stop" -> {
                    AlarmBuzzService.stop(this)
                    result.success(null)
                }
                "activeAlarmId" -> {
                    val id = getSharedPreferences(AlarmBuzzService.PREFS, Context.MODE_PRIVATE)
                        .getInt(AlarmBuzzService.KEY_ACTIVE_ID, -1)
                    result.success(if (id > 0) id else null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
