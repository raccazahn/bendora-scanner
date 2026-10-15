import 'dart:ui'; // <-- Added this import
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  // Catch all uncaught Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  runApp(
    const MaterialApp(
      title: 'Bendora Scanner',
      debugShowCheckedModeBanner: false,
      home: ErrorBoundary(child: LoginScreen()),
    ),
  );
}

// Widget that catches all errors and displays them on screen
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Catch any async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      setState(() {
        _error = '$error\n\n$stack';
      });
      return true; // Prevent app crash
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'App Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
