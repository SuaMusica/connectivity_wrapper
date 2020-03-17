import 'dart:async';

import 'package:connectivityswift/connectivityswift.dart';
import 'package:connectivity_wrapper/src/service/connectivity_service.dart';
import 'package:connectivity_wrapper/src/utils/constants.dart';
import 'package:flutter/material.dart';

/// [ConnectivityProvider] event ChangeNotifier class for ConnectivityStatus .
/// which extends [ChangeNotifier].
enum ConnectivityStatusType { Connectivity, Ping, AlwaysOnline, AlwaysOffline }

class ConnectivityProvider extends ChangeNotifier {
  StreamController<ConnectivityStatus> connectivityController =
      StreamController<ConnectivityStatus>();

  StreamSubscription<ConnectivityResult> _subscription;
  Stream<ConnectivityStatus> get connectivityStream =>
      connectivityController.stream;
  ConnectivityStatusType type;
  ConnectivityProvider({
    type = ConnectivityStatusType.Ping,
  }) {
    _updateConnectivityStatus();
  }

  @mustCallSuper
  void dispose() {
    if (_subscription != null) {
      _subscription.cancel();
    }
    super.dispose();
  }

  _updateConnectivityStatus() async {
    if (type == ConnectivityStatusType.Connectivity) {
      var connectivityResult = await (Connectivityswift().checkConnectivity());
      connectivityController.add(
        connectivityResult == ConnectivityResult.none
            ? ConnectivityStatus.DISCONNECTED
            : ConnectivityStatus.CONNECTED,
      );
      _subscription = Connectivityswift()
          .onConnectivityChanged
          .listen((ConnectivityResult result) {
        connectivityController.add(
          result == ConnectivityResult.none
              ? ConnectivityStatus.DISCONNECTED
              : ConnectivityStatus.CONNECTED,
        );
      });
    } else if (type == ConnectivityStatusType.AlwaysOffline) {
      connectivityController.add(
        ConnectivityStatus.DISCONNECTED,
      );
    } else if (type == ConnectivityStatusType.AlwaysOnline) {
      connectivityController.add(
        ConnectivityStatus.CONNECTED,
      );
    } else {
      connectivityController.add(
        ConnectivityStatus.CONNECTED,
      );
      ConnectivityService()
          .onStatusChange
          .listen((ConnectivityStatus connectivityStatus) {
        connectivityController.add(connectivityStatus);
      });
    }
  }
}
