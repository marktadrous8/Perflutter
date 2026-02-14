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
      appBar: AppBar(title: const Text('Perflutter Example')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: 'DetailsPage'),
                builder: (_) => const ExampleDetailsPage(),
              ),
            );
          },
          child: const Text('Open details screen'),
        ),
      ),
    );
  }
}

class ExampleDetailsPage extends StatelessWidget {
  const ExampleDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: const Center(
        child: Text('Long press or tap the floating chart button to open Perflutter report.'),
      ),
    );
  }
}
