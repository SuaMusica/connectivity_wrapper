import 'package:connectivity_wrapper/src/providers/connectivity_provider.dart';
import 'package:connectivity_wrapper/src/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConnectivityWidgetWrapper extends StatelessWidget {
  /// The [child] contained by the ConnectivityWidgetWrapper.
  final Widget child;

  /// The [offlineWidget] contained by the ConnectivityWidgetWrapper.
  final Widget? offlineWidget;

  /// The decoration to paint behind the [child].
  final Decoration? decoration;

  /// The color to paint behind the [child].
  final Color? color;

  /// Disconnected message.
  final String? message;

  /// If non-null, the style to use for this text.
  final TextStyle? messageStyle;

  /// widget height.
  final double? height;

  /// widget height.
  final bool stacked;

  /// Disable the user interaction with child widget
  final bool disableInteraction;

  /// How to align the offline widget.
  final AlignmentGeometry? alignment;

  const ConnectivityWidgetWrapper({
    Key? key,
    required this.child,
    this.color,
    this.decoration,
    this.message,
    this.messageStyle,
    this.height,
    this.offlineWidget,
    this.stacked = true,
    this.alignment,
    this.disableInteraction = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var finalOfflineWidget = Align(
      alignment: alignment ?? Alignment.bottomCenter,
      child: offlineWidget ??
          Container(
            height: height ?? defaultHeight,
            width: MediaQuery.of(context).size.width,
            decoration: decoration ??
                BoxDecoration(color: color ?? Colors.red.shade300),
            child: Center(
              child: Text(
                message ?? disconnectedMessage,
                style: messageStyle ?? defaultMessageStyle,
              ),
            ),
          ),
    );
    return Consumer<ConnectivityProvider>(
      builder: (_, notifier, consumerChild) {
        final isOffline = !notifier.isConnected();
        return stacked
            ? Stack(
                children: <Widget>[
                  consumerChild!,
                  disableInteraction && isOffline
                      ? Column(
                          children: <Widget>[
                            Flexible(
                              child: Container(
                                decoration: decoration ??
                                    BoxDecoration(
                                      color: Colors.black38,
                                    ),
                              ),
                            )
                          ],
                        )
                      : Container(),
                  isOffline ? finalOfflineWidget : Container(),
                ],
              )
            : (isOffline ? finalOfflineWidget : consumerChild!);
      },
      child: child,
    );
  }
}
