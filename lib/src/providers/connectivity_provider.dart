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
  StreamController<ConnectivityStatus> connectivityController =
      StreamController<ConnectivityStatus>();

  StreamSubscription<ConnectivityResult> _subscription;
  Stream<ConnectivityStatus> get stream => connectivityController.stream;
  ConnectivityStatusType type;
  final Connectivityswift _connectivity = Connectivityswift();

  @mustCallSuper
  void dispose() {
    if (_subscription != null) {
      _subscription.cancel();
    }
    super.dispose();
  }

  void changeStatus(ConnectivityResult result) =>
      result == ConnectivityResult.none ? setOffline() : setOnline();

  void setOnline() => connectivityController.add(ConnectivityStatus.CONNECTED);
  void setOffline() =>
      connectivityController.add(ConnectivityStatus.DISCONNECTED);

  _updateConnectivityStatus() async {
    if (type == ConnectivityStatusType.Ping) {
      setOnline();
      ConnectivityService()
          .onStatusChange
          .listen((ConnectivityStatus connectivityStatus) {
        connectivityController.add(connectivityStatus);
      });
    } else if (type == ConnectivityStatusType.AlwaysOffline) {
      setOffline();
    } else if (type == ConnectivityStatusType.AlwaysOnline) {
      setOnline();
    } else {
      var connectivityResult = await (_connectivity.checkConnectivity());
      changeStatus(connectivityResult);
      _subscription = _connectivity.onConnectivityChanged
          .listen((ConnectivityResult result) => changeStatus(result));
    }
  }
}
