import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tracker.dart';

class PerflutterNavigatorObserver extends AutoRouterObserver {
  final WidgetRef ref;
  PerflutterNavigatorObserver(this.ref);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logScreen(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _logScreen(previousRoute);
    }
  }

  @override
  void didInitTabRoute(TabPageRoute route, TabPageRoute? previousRoute) {
    _logTab(route);
  }

  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) {
    _logTab(route);
  }

  void _logScreen(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null) {
      Future.microtask(() {
        ref.read(perflutterTrackerProvider.notifier).onScreenChanged(name);
      });
    }
  }

  void _logTab(TabPageRoute route) {
    Future.microtask(() {
      ref.read(perflutterTrackerProvider.notifier).onScreenChanged("Tab: ${route.name}");
    });
  }
}
