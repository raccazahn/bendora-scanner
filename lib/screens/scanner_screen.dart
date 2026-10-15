import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';
import '../services/scanner_service.dart';
import '../models/event_pack_model.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _db = DatabaseService();
  final _scanner = ScannerService();
  MobileScannerController controller = MobileScannerController();
  
  EventPackModel? _eventPack;
  bool _isProcessing = false;
  ScanResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadEventPack();
  }

  Future<void> _loadEventPack() async {
    final pack = await _db.getEventPack();
    setState(() => _eventPack = pack);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _eventPack == null) return;
    
    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    controller.stop(); // Pause camera

    // Get assigned gate ID from event pack (or null if not assigned to a specific gate)
    final result = await _scanner.processScan(code, _eventPack!, _eventPack!.gateId);

    setState(() {
      _lastResult = result;
      _isProcessing = false;
    });

    // Auto-resume after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _lastResult = null);
        controller.start();
      }
    });
    }

  @override
  Widget build(BuildContext context) {
    if (_eventPack == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // Top Overlay: Event Info
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text('Scanner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
          ),
                  const SizedBox(height: 8),
                  Text(_eventPack!.eventName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  if (_eventPack!.gateName != null)
                    Text('Gate: ${_eventPack!.gateName}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
          
          // Center Overlay: Scanning Frame
          if (_lastResult == null)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner, size: 64, color: Colors.blue),
              ),
            ),

          // Bottom Overlay: Result
          if (_lastResult != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _lastResult!.type == ScanResultType.valid ? Colors.green : Colors.red,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _lastResult!.type == ScanResultType.valid ? Icons.check_circle : Icons.cancel,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lastResult!.message.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (_lastResult!.ticket != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lastResult!.ticket!.publicTicketId,
                        style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'monospace'),
                      ),
                      Text(
                        _lastResult!.ticket!.ticketType,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
