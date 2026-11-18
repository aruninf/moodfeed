package com.moodfeed.moodfeed

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// The only bridge between Dart and Android. Deliberately small: it answers
/// questions the framework cannot, and nothing else.
class MoodFeedPlugin(private val context: Context) {

    fun handle(method: String, json: String?, result: MethodChannel.Result) {
        when (method) {
            "foregroundPackage" -> result.success(foregroundPackage())
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccessSettings" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    context.startActivity(intent)
                } catch (e: Exception) {
                    context.startActivity(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                }
                result.success(null)
            }
            "closeForegroundApp" -> {
                context.startActivity(
                    Intent(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_HOME)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            }
            "isPackInstalled" -> result.success(isPackInstalled())
            "pushTimeline" -> result.success(pushTimeline(json))
            else -> result.notImplemented()
        }
    }

    private fun foregroundPackage(): String? {
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = manager.queryEvents(now - 10_000, now)
        val event = UsageEvents.Event()
        var last: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                last = event.packageName
            }
        }
        return last
    }

    private fun hasUsageAccess(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        if (mode == AppOpsManager.MODE_ALLOWED) return true

        return try {
            val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 1000 * 60, now)
            stats != null && stats.isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }

    private fun isPackInstalled(): Boolean = try {
        context.packageManager.getPackageInfo(PACK_PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /// Silent when the pack is absent or signed with another key: a missing
    /// provider must never crash MoodFeed.
    private fun pushTimeline(json: String?): Boolean {
        if (json == null) return false
        return try {
            val bundle = Bundle().apply { putString("json", json) }
            context.contentResolver.call(
                Uri.parse("content://$PACK_PACKAGE.state"),
                "set_state",
                null,
                bundle
            )
            true
        } catch (e: SecurityException) {
            false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    companion object {
        const val CHANNEL = "com.moodfeed/platform"
        const val PACK_PACKAGE = "com.instagram.android.moodfeed"

        fun register(engine: FlutterEngine, context: Context) {
            val plugin = MoodFeedPlugin(context.applicationContext)
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler { call, result ->
                    plugin.handle(call.method, call.argument<String>("json"), result)
                }
        }
    }
}
