import 'package:connectivity_wrapper/connectivity_wrapper.dart';
import 'package:connectivity_wrapper_example/screens/scaffold_example_screen.dart';
import 'package:connectivity_wrapper_example/utils/strings.dart';
import 'package:connectivity_wrapper_example/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'custom_offline_widget_screen.dart';
import 'network_aware_widget_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connectivity Wrapper Example"),
      ),
      body: ConnectivityWidgetWrapper(
        child: ListView(
          children: <Widget>[
            Consumer<ConnectivityProvider>(
              builder: (_, provider, __) {
                final reachability = provider.reachabilityStatus?.name ?? '…';
                return ListTile(
                  title: Text('Reachability (native)'),
                  subtitle: Text(
                    '$reachability · connected=${provider.isConnected()} · limited=${provider.isLimited}',
                  ),
                );
              },
            ),
            Divider(),
            ListTile(
              title: Text(Strings.example1),
              onTap: () {
                AppRoutes.push(context, ScaffoldExampleScreen());
              },
            ),
            Divider(),
            ListTile(
              title: Text(Strings.example2),
              onTap: () {
                AppRoutes.push(context, CustomOfflineWidgetScreen());
              },
            ),
            Divider(),
            ListTile(
              title: Text(Strings.example3),
              onTap: () {
                AppRoutes.push(context, NetworkAwareWidgetScreen());
              },
            ),
            Divider(),
          ],
        ),
      ),
    );
  }
}
