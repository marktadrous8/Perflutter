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
  perflutter: ^0.0.5
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

## Example Use Cases (in `example/lib/main.dart`)

The example app provides 2 screens that you can run individually to capture screenshots:

*   **Normal screen:** Normal UI updates with moderate rendering load.
*   **Heavy screen:** Includes a circular loader and a button (`Run temporary heavy work`) that intentionally blocks the UI thread for a short time to demonstrate jank/dropped frames and visible loader glitching.

Use the floating Perflutter trigger button on each screen to compare metrics.

## How Frames Are Calculated

Perflutter listens to Flutter `FrameTiming` samples and tracks frames for the currently active screen.

For each frame:

*   `totalFrames` increases by `1`.
*   The frame is counted as dropped when **either**:
    *   `buildDuration` (UI thread) > frame budget, or
    *   `rasterDuration` (raster thread) > frame budget.

Frame budget is computed from the device refresh rate:

*   `frameBudgetMicros = 1,000,000 / refreshRate`
*   If refresh rate is unavailable, fallback is `16,666 µs` (60Hz).

## What The Colors Mean

### Performance Color (based on drop rate)

*   **Green:** `dropRate < 5%`
*   **Orange:** `5% <= dropRate < 15%`
*   **Red:** `dropRate >= 15%`

### Memory Color (based on peak memory in MB)

*   **Green:** `memory < 350 MB`
*   **Orange:** `350 MB <= memory < 600 MB`
*   **Red:** `memory >= 600 MB`
