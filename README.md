# Perflutter

Perflutter is a lightweight, zero-configuration performance tracking tool for Flutter applications. It helps you monitor frame drops, memory usage, and screen loading times with a simple overlay inspector.


## Features

*   **Zero Configuration:** No external state management usage (no Riverpod/Provider setup required).
*   **Plug & Play:** Simply wrap your app and add an observer.
*   **Invisible Trigger:** Activate the report screen via a hidden **Long Press** or a floating button.
*   **Overlay Support:** Works on top of everything (Dialogs, BottomSheets) and doesn't require a Navigator context.
*   **Metrics:** Connects `FrameTiming` to track dropped frames (jank) and memory approximations per screen.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  perflutter: ^0.0.1
```

## Usage

### 1. Add the Navigator Observer

To track screen transitions, add `PerflutterNavigatorObserver` to your `MaterialApp` or Router.

**Standard MaterialApp:**

```dart
import 'package:perflutter/perflutter.dart';

MaterialApp(
  navigatorObservers: [
    PerflutterNavigatorObserver(), // <--- Add this
  ],
  home: HomePage(),
);
```

**AutoRouter:**

```dart
MaterialApp.router(
  routerConfig: _appRouter.config(
    navigatorObservers: () => [
      PerflutterNavigatorObserver(), // <--- Add this
    ],
  ),
);
```

### 2. Wrap your App with the Trigger

Wrap your `MaterialApp` builder (or `home`) with `PerflutterTrigger` to enable the inspector.

```dart
import 'package:perflutter/perflutter.dart';

MaterialApp(
  builder: (context, child) {
    return PerflutterTrigger(
      triggerMode: PerflutterTriggerMode.longPress, // Options: longPress, floatingButton
      child: child ?? const SizedBox(),
    );
  },
  // ...
);
```

## How to Access

*   **Long Press Mode (Recommended):** Long press anywhere on the screen (on non-interactive areas) to open the performance report.
*   **Floating Button Mode:** A floating chart button will appear on the bottom right.
