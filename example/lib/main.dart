import 'package:flutter/material.dart';
import 'package:perflutter/perflutter.dart';

void main() {
  runApp(const PerflutterExampleApp());
}

class PerflutterExampleApp extends StatelessWidget {
  const PerflutterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [PerflutterNavigatorObserver()],
      builder: (context, child) {
        return PerflutterTrigger(
          triggerMode: PerflutterTriggerMode.floatingButton,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perflutter Example Use Cases')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Open each screen individually and use Perflutter trigger button to observe frame behavior.',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'HealthyScreen'),
                  builder: (_) => const HealthyScreen(),
                ),
              );
            },
            child: const Text('1) Healthy screen (good frame health)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'BalancedScreen'),
                  builder: (_) => const BalancedScreen(),
                ),
              );
            },
            child: const Text('2) Balanced screen (normal workload)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'HeavyScreen'),
                  builder: (_) => const HeavyScreen(),
                ),
              );
            },
            child: const Text('3) Heavy screen (jank demo)'),
          ),
        ],
      ),
    );
  }
}

class HealthyScreen extends StatefulWidget {
  const HealthyScreen({super.key});

  @override
  State<HealthyScreen> createState() => _HealthyScreenState();
}

class _HealthyScreenState extends State<HealthyScreen> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Healthy Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Light and responsive UI. Interactions should stay smooth with low dropped frames.',
            ),
            const SizedBox(height: 16),
            Text('Tap count: $counter'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => counter++),
              child: const Text('Tap quickly'),
            ),
            const SizedBox(height: 16),
            const Expanded(child: _SmoothList()),
          ],
        ),
      ),
    );
  }
}

class _SmoothList extends StatelessWidget {
  const _SmoothList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 30,
      itemBuilder: (_, index) => ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text('Healthy item ${index + 1}'),
      ),
    );
  }
}

class BalancedScreen extends StatefulWidget {
  const BalancedScreen({super.key});

  @override
  State<BalancedScreen> createState() => _BalancedScreenState();
}

class _BalancedScreenState extends State<BalancedScreen> {
  double slider = 0.3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balanced Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Moderate UI updates: should usually remain smooth with occasional tiny pressure.',
            ),
            const SizedBox(height: 12),
            Slider(
              value: slider,
              onChanged: (value) => setState(() => slider = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                ),
                itemCount: 36,
                itemBuilder: (_, index) {
                  final colorSeed = (index * 7) % 255;
                  return Card(
                    color: Color.fromARGB(255, colorSeed, 120, 255 - colorSeed),
                    child: Center(
                      child: Text(
                        'Cell ${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeavyScreen extends StatefulWidget {
  const HeavyScreen({super.key});

  @override
  State<HeavyScreen> createState() => _HeavyScreenState();
}

class _HeavyScreenState extends State<HeavyScreen> {
  bool isRunningHeavyWork = false;
  String status = 'Idle';

  void _runHeavyWork() {
    if (isRunningHeavyWork) {
      return;
    }

    setState(() {
      isRunningHeavyWork = true;
      status = 'Heavy work started...';
    });

    final stopwatch = Stopwatch()..start();
    var accumulator = 0.0;
    while (stopwatch.elapsedMilliseconds < 2500) {
      final data = List<int>.generate(12000, (i) => (12000 - i) % 97);
      data.sort();
      for (final value in data) {
        accumulator += value / 3.14159;
      }
    }
    stopwatch.stop();

    setState(() {
      isRunningHeavyWork = false;
      status =
          'Completed in ${stopwatch.elapsedMilliseconds} ms. Result: ${accumulator.toStringAsFixed(1)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heavy Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is intentionally heavy. Press the button to block the UI thread temporarily and observe jank frames.',
            ),
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(strokeWidth: 5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _runHeavyWork,
              child: const Text('Run temporary heavy work'),
            ),
            const SizedBox(height: 8),
            Text('Status: $status'),
            const SizedBox(height: 12),
            const Text(
              'Expected behavior: while heavy work runs, the circular loading can freeze/glitch and dropped frames should increase.',
            ),
          ],
        ),
      ),
    );
  }
}
