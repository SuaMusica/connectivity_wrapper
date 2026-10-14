import Flutter
import UIKit

public class ConnectivityWrapperPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let connectivityManager = NetworkConnectivityManager()
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ConnectivityWrapperPlugin()
        let methodChannel = FlutterMethodChannel(
            name: "com.suamusica/connectivity_wrapper",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.suamusica/connectivity_wrapper/status",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCurrentStatus":
            result(connectivityManager.currentStatus().toWire())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        connectivityManager.onStatusChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.eventSink?(status.toWire())
            }
        }
        connectivityManager.startMonitoring()
        events(connectivityManager.currentStatus().toWire())
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        connectivityManager.stopMonitoring()
        connectivityManager.onStatusChanged = nil
        eventSink = nil
        return nil
    }
}
