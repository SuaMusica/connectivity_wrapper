import 'dart:async';
import 'dart:io';

import 'package:connectivity_wrapper/src/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native validated connectivity (same semantics as smplayer NetworkConnectivityManager).
class NativeConnectivity {
  NativeConnectivity._();

  static const MethodChannel _methodChannel =
      MethodChannel('com.suamusica/connectivity_wrapper');
  static const EventChannel _eventChannel =
      EventChannel('com.suamusica/connectivity_wrapper/status');

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<NetworkReachabilityStatus> getCurrentStatus() async {
    if (!isSupported) {
      return NetworkReachabilityStatus.online;
    }
    final wire = await _methodChannel.invokeMethod<String>('getCurrentStatus');
    return _parseWire(wire);
  }

  static Stream<NetworkReachabilityStatus> get onStatusChange {
    if (!isSupported) {
      return Stream.value(NetworkReachabilityStatus.online);
    }
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => _parseWire(event as String?));
  }

  static NetworkReachabilityStatus _parseWire(String? wire) {
    switch (wire) {
      case 'online':
        return NetworkReachabilityStatus.online;
      case 'limited':
        return NetworkReachabilityStatus.limited;
      case 'offline':
      default:
        return NetworkReachabilityStatus.offline;
    }
  }
}
