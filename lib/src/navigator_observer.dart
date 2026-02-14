import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'tracker.dart';

/// Navigator observer that forwards route changes to [PerflutterTracker].
class PerflutterNavigatorObserver extends AutoRouterObserver {
  /// Creates the observer.
  PerflutterNavigatorObserver();

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
        PerflutterTracker.instance.onScreenChanged(name);
      });
    }
  }

  void _logTab(TabPageRoute route) {
    Future.microtask(() {
      PerflutterTracker.instance.onScreenChanged("Tab: ${route.name}");
    });
  }
}
