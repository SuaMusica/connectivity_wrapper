import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_wrapper/src/platform/native_connectivity.dart';
import 'package:connectivity_wrapper/src/service/connectivity_service.dart';
import 'package:connectivity_wrapper/src/utils/constants.dart';
import 'package:flutter/material.dart';

/// [ConnectivityProvider] event ChangeNotifier class for ConnectivityStatus .
/// which extends [ChangeNotifier].

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({
    this.type = ConnectivityStatusType.Ping,
    this.delay = const Duration(seconds: 0),
  }) {
    _updateConnectivityStatus();
  }

  bool isConnected({bool ignoreOfflineForced = false}) =>
      (_isConnected ?? true) && (!isOfflineForced || ignoreOfflineForced);

  bool isConnected2({bool ignoreOfflineForced = false}) =>
      (_isConnected ?? true) &&
      (!isOfflineForced || ignoreOfflineForced) &&
      !isLimited;

  /// Rede com transporte mas sem internet validada (captive portal, etc.).
  bool get isLimited => reachabilityStatus == NetworkReachabilityStatus.limited;

  NetworkReachabilityStatus? get reachabilityStatus => _reachabilityStatus;

  bool? _isConnected;
  bool? _isOfflineForced;
  NetworkReachabilityStatus? _reachabilityStatus;

  bool get isOfflineForced => _isOfflineForced ?? false;

  void setOfflineForced(bool value, {bool shouldNotify = true}) {
    _isOfflineForced = value;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  StreamSubscription<NetworkReachabilityStatus>? _nativeSubscription;
  ConnectivityStatusType type;
  Duration delay;
  final _connectivity = Connectivity();

  @mustCallSuper
  void dispose() {
    _subscription?.cancel();
    _nativeSubscription?.cancel();
    super.dispose();
  }

  void changeResult(List<ConnectivityResult> result) =>
      result.contains(ConnectivityResult.none) ? setOffline() : setOnline();
  void changeStatus(ConnectivityStatus result) =>
      result == ConnectivityStatus.DISCONNECTED ? setOffline() : setOnline();

  void changeType(ConnectivityStatusType t) {
    if (type != t) {
      type = t;
      _updateConnectivityStatus();
    }
  }

  void changeToConnectivity() =>
      changeType(ConnectivityStatusType.Connectivity);

  void setOnline() {
    _isConnected = true;
    notifyListeners();
  }

  void setOffline() {
    _isConnected = false;
    notifyListeners();
  }

  void _applyReachability(NetworkReachabilityStatus status) {
    _reachabilityStatus = status;
    if (status == NetworkReachabilityStatus.online) {
      setOnline();
    } else {
      setOffline();
    }
  }

  void _listenValidatedConnectivity() {
    _nativeSubscription?.cancel();
    _nativeSubscription = NativeConnectivity.onStatusChange.listen(
      _applyReachability,
    );
    NativeConnectivity.getCurrentStatus().then(_applyReachability);
  }

  _updateConnectivityStatus() async {
    _subscription?.cancel();
    _nativeSubscription?.cancel();

    if (type == ConnectivityStatusType.Ping) {
      setOnline();
      ConnectivityService()
          .onStatusChange
          .listen((ConnectivityStatus connectivityStatus) {
        if (connectivityStatus == ConnectivityStatus.CONNECTED) {
          setOnline();
        } else {
          setOffline();
        }
      });
    } else if (type == ConnectivityStatusType.Validated) {
      _listenValidatedConnectivity();
    } else if (type == ConnectivityStatusType.AlwaysOffline) {
      setOffline();
    } else if (type == ConnectivityStatusType.AlwaysOnline) {
      setOnline();
    } else {
      var connectivityResult = await (_connectivity.checkConnectivity());
      changeResult(connectivityResult);
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> result) {
          if (delay.inMilliseconds == 0) {
            changeResult(result);
          } else {
            Future.delayed(delay, () => changeResult(result));
          }
        },
      );
    }
  }
}
