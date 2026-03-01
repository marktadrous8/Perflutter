import 'dart:ui';

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
                  settings: const RouteSettings(name: 'NormalScreen'),
                  builder: (_) => const NormalScreen(),
                ),
              );
            },
            child: const Text('1) Normal screen (normal workload)'),
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
            child: const Text('2) Heavy screen (jank demo)'),
          ),
        ],
      ),
    );
  }
}

class NormalScreen extends StatefulWidget {
  const NormalScreen({super.key});

  @override
  State<NormalScreen> createState() => _NormalScreenState();
}

class _NormalScreenState extends State<NormalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Normal Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Moderate UI updates: should usually remain smooth with occasional tiny pressure.',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                ),
                itemCount: 120,
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

class _HeavyScreenState extends State<HeavyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  double stressLevel = 1;
  String status = 'Raster stress running';

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  int get layerCount {
    final level = stressLevel.round();
    switch (level) {
      case 1:
        return 1;
      case 2:
        return 8;
      case 3:
        return 12;
      case 4:
        return 16;
      case 5:
        return 20;
      case 6:
        return 24;
      case 7:
        return 28;
      case 8:
        return 32;
      case 9:
        return 36;
      case 10:
        return 40;
      default:
        return 20;
    }
  }

  double get blurSigma {
    final level = stressLevel.round();
    switch (level) {
      case 1:
        return 1;
      case 2:
        return 8;
      case 3:
        return 12;
      case 4:
        return 16;
      case 5:
        return 20;
      case 6:
        return 24;
      case 7:
        return 28;
      case 8:
        return 32;
      case 9:
        return 36;
      case 10:
        return 40;
      default:
        return 20;
    }
  }

  String get stressLabel {
    final level = stressLevel.round();
    if (level <= 2) {
      return 'Low stress (healthier)';
    }
    if (level == 3) {
      return 'Medium stress';
    }
    if (level <= 8) {
      return 'High stress (heavy)';
    }
    if (level <= 10) {
      return 'Very high stress (intense)';
    }
    return 'Extreme stress (maximum)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heavy Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Raster-heavy demo: many animated blur layers run together to stress raster thread and increase dropped frames.',
              ),
              const SizedBox(height: 16),
              Container(
                height: 320,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final t = controller.value;
                    return Stack(
                      children: [
                        for (var i = 0; i < layerCount; i++)
                          _RasterLayer(index: i, t: t, blurSigma: blurSigma),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    minHeight: 8,
                    value: controller.value,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Stress level: ${stressLevel.round()} - $stressLabel',
              ),
              Slider(
                value: stressLevel,
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (value) => setState(() => stressLevel = value),
              ),
              const SizedBox(height: 8),
              Text('Status: $status'),
              const SizedBox(height: 12),
              const Text(
                'Starts at low by default. Move to high for heavier raster load and more dropped frames.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RasterLayer extends StatelessWidget {
  const _RasterLayer({
    required this.index,
    required this.t,
    required this.blurSigma,
  });

  final int index;
  final double t;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final wave = (t + (index * 0.07)) % 1.0;
    final left = (wave * 340) - 70;
    final top = (((1 - wave) * 250) + ((index % 5) * 12)) - 30;
    final size = 80 + ((index % 4) * 18);
    final hue = (index * 33) % 360;

    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: wave * 6.28,
        child: Opacity(
          opacity: 0.35,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                width: size.toDouble(),
                height: size.toDouble(),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HSVColor.fromAHSV(1, hue.toDouble(), 0.8, 0.9).toColor(),
                      HSVColor.fromAHSV(
                        1,
                        (hue + 80).toDouble() % 360,
                        0.8,
                        0.9,
                      ).toColor(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
