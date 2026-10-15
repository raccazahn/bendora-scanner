import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/event_pack_model.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  Map<String, dynamic>? _assignment;
  EventPackModel? _eventPack;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadData();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final assignment = await ApiService.getAssignment();
    final pack = await _db.getEventPack();
    
    setState(() {
      _assignment = assignment;
      _eventPack = pack;
      _isLoading = false;
    });
  }

  Future<void> _downloadEventPack() async {
    setState(() => _isDownloading = true);
    
    final currentVersion = await _db.getCurrentPackVersion();
    final newPack = await ApiService.getEventPack(currentVersion);
    
    if (newPack != null) {
      await _db.saveEventPackTransactionally(newPack);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event Pack updated successfully!')),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event Pack is already up to date.')),
      );
    }
    
    setState(() => _isDownloading = false);
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    await _db.clearDatabase();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/'); // Or rebuild with LoginScreen
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isReady = _eventPack != null && _assignment != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Home'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Assignment Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ASSIGNMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildInfoRow('Device', _assignment?['device_code'] ?? 'Unknown'),
                      _buildInfoRow('Event', _assignment?['event_name'] ?? 'Not Assigned'),
                      _buildInfoRow('Gate', _assignment?['gate_name'] ?? 'Not Assigned'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Event Pack Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EVENT PACK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildInfoRow('Version', _eventPack?.version.toString() ?? '0'),
                      _buildInfoRow('Tickets', _eventPack?.tickets.length.toString() ?? '0'),
                      _buildInfoRow('Security', 'Ed25519 ✓'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _downloadEventPack,
                        icon: _isDownloading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download),
                        label: Text(_isDownloading ? 'Downloading...' : 'Download / Update Pack'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Readiness Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isReady ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isReady ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(isReady ? Icons.check_circle : Icons.warning_amber_rounded, 
                         color: isReady ? Colors.green : Colors.orange, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReady ? 'READY FOR SCANNING' : 'NOT READY',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: isReady ? Colors.green.shade900 : Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            isReady 
                                ? 'Local database is synchronized and ready for offline use.' 
                                : 'Please download the Event Pack to enable offline scanning.',
                            style: TextStyle(color: isReady ? Colors.green.shade800 : Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              ElevatedButton(
                onPressed: isReady ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())) : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: isReady ? Colors.blue : Colors.grey,
                ),
                child: const Text('START SCANNING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                icon: const Icon(Icons.history),
                label: const Text('Scan History & Sync'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}
