package com.suamusica.connectivity_wrapper

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ConnectivityWrapperPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var applicationContext: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var streamHandler: ConnectivityStatusStreamHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val messenger = binding.binaryMessenger

        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        streamHandler = ConnectivityStatusStreamHandler(applicationContext)
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).also {
            it.setStreamHandler(streamHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        streamHandler = null
        methodChannel = null
        eventChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentStatus" -> {
                val status = NetworkConnectivityManager(applicationContext).currentStatus()
                result.success(status.toWire())
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "com.suamusica/connectivity_wrapper"
        private const val EVENT_CHANNEL = "com.suamusica/connectivity_wrapper/status"
    }
}

private class ConnectivityStatusStreamHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var manager: NetworkConnectivityManager? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        manager = NetworkConnectivityManager(context) { status ->
            val wire = status.toWire()
            mainHandler.post {
                eventSink?.success(wire)
            }
        }
        manager?.startMonitoring()
        val initial = manager?.currentStatus()?.toWire()
        mainHandler.post {
            eventSink?.success(initial)
        }
    }

    override fun onCancel(arguments: Any?) {
        manager?.stopMonitoring()
        manager = null
        eventSink = null
    }
}
