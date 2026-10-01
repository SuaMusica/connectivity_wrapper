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

  bool isConnected({bool ignoreOfflineForced = false}) {
    if (!ignoreOfflineForced && isOfflineForced) {
      return false;
    }

    return switch (type) {
      ConnectivityStatusType.AlwaysOffline => false,
      ConnectivityStatusType.AlwaysOnline => true,
      ConnectivityStatusType.Ping => _isConnected ?? true,
      ConnectivityStatusType.Validated ||
      ConnectivityStatusType.Connectivity =>
        (_isConnected ?? true) && _hasValidatedInternet,
    };
  }

  bool get isOfflineForced => _isOfflineForced ?? false;

  /// Rede com transporte mas sem internet validada (captive portal, etc.).
  bool get isLimited => reachabilityStatus == NetworkReachabilityStatus.limited;

  NetworkReachabilityStatus? get reachabilityStatus => _reachabilityStatus;

  bool get _hasValidatedInternet =>
      _reachabilityStatus == NetworkReachabilityStatus.online;

  bool? _isConnected;
  bool? _isOfflineForced;
  NetworkReachabilityStatus? _reachabilityStatus;

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
    if (type == ConnectivityStatusType.Validated) {
      if (status == NetworkReachabilityStatus.online) {
        setOnline();
      } else {
        setOffline();
      }
    } else {
      notifyListeners();
    }
  }

  void _listenValidatedConnectivity() {
    _nativeSubscription?.cancel();
    _nativeSubscription = NativeConnectivity.onStatusChange.listen(
      _applyReachability,
    );
    NativeConnectivity.getCurrentStatus().then(_applyReachability);
  }

  Future<void> _updateConnectivityStatus() async {
    _subscription?.cancel();
    _nativeSubscription?.cancel();

    switch (type) {
      case ConnectivityStatusType.Ping:
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
      case ConnectivityStatusType.Validated:
        _listenValidatedConnectivity();
      case ConnectivityStatusType.AlwaysOffline:
        setOffline();
      case ConnectivityStatusType.AlwaysOnline:
        setOnline();
      case ConnectivityStatusType.Connectivity:
        _listenValidatedConnectivity();
        final connectivityResult = await _connectivity.checkConnectivity();
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
