import 'package:connectivity_wrapper/src/providers/connectivity_provider.dart';
import 'package:connectivity_wrapper/src/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

///[ConnectivityAppWrapper] is a StatelessWidget.

class ConnectivityAppWrapper extends StatelessWidget {
  /// [app] will accept MaterialApp or CupertinoApp must be non-null
  /// [type] will accept ConnectivityStatusType enum
  final Widget app;
  final ConnectivityStatusType type;
  final Duration delay;
  const ConnectivityAppWrapper({
    Key? key,
    required this.app,
    this.type = ConnectivityStatusType.Ping,
    this.delay = const Duration(seconds: 0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ConnectivityProvider>(
      create: (_) => ConnectivityProvider(
        type: type,
        delay: delay,
      ),
      child: app,
    );
  }
}
