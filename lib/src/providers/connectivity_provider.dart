import 'dart:async';

import 'package:connectivityswift/connectivityswift.dart';

import 'package:connectivity_wrapper/src/service/connectivity_service.dart';
import 'package:connectivity_wrapper/src/utils/constants.dart';
import 'package:flutter/material.dart';

/// [ConnectivityProvider] event ChangeNotifier class for ConnectivityStatus .
/// which extends [ChangeNotifier].

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({
    this.type = ConnectivityStatusType.Ping,
  }) {
    _updateConnectivityStatus();
  }

  bool isConnected() => _isConnected ?? true;
  bool _isConnected;

  StreamSubscription<ConnectivityResult> _subscription;
  ConnectivityStatusType type;
  final Connectivityswift _connectivity = Connectivityswift();

  @mustCallSuper
  void dispose() {
    if (_subscription != null) {
      _subscription.cancel();
    }
    super.dispose();
  }

  void changeResult(ConnectivityResult result) =>
      result == ConnectivityResult.none ? setOffline() : setOnline();
  void changeStatus(ConnectivityStatus result) =>
      result == ConnectivityStatus.DISCONNECTED ? setOffline() : setOnline();

  void setOnline() {
    _isConnected = true;
    notifyListeners();
  }

  void setOffline() {
    _isConnected = false;
    notifyListeners();
  }

  _updateConnectivityStatus() async {
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
    } else if (type == ConnectivityStatusType.AlwaysOffline) {
      setOffline();
    } else if (type == ConnectivityStatusType.AlwaysOnline) {
      setOnline();
    } else {
      var connectivityResult = await (_connectivity.checkConnectivity());
      changeResult(connectivityResult);
      _subscription = _connectivity.onConnectivityChanged
          .listen((ConnectivityResult result) => changeResult(result));
    }
  }
}
