import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../models/scan_record_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseService();
  List<ScanRecordModel> _records = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final records = await _db.getUnsyncedScans();
    // For display, we might want all records, but let's start with unsynced + recent synced
    // For simplicity, let's just fetch all and sort by date desc
    final db = await _db.database;
    final maps = await db.query('scan_records', orderBy: 'scanned_at DESC', limit: 100);
    
    setState(() {
      _records = maps.map((e) => ScanRecordModel.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    
    final unsynced = await _db.getUnsyncedScans();
    if (unsynced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending scans to sync.')));
      setState(() => _isSyncing = false);
      return;
    }

    final success = await ApiService.syncScans(unsynced);
    
    if (success) {
      for (final record in unsynced) {
        await _db.markScanAsSynced(record.localScanId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully synced ${unsynced.length} scans!')),
      );
      await _loadHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed. Check your connection.'), backgroundColor: Colors.red),
      );
    }
    
    setState(() => _isSyncing = false);
  }

  Color _getResultColor(String result) {
    if (result == 'VALID') return Colors.green;
    if (result == 'ALREADY_USED' || result == 'WRONG_GATE' || result == 'WRONG_EVENT') return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncNow,
              icon: _isSyncing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Syncing...' : 'Sync Pending Scans'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('No scan records found.'))
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          final time = DateFormat('HH:mm:ss').format(record.scannedAt);
                          final date = DateFormat('MMM d').format(record.scannedAt);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getResultColor(record.scanResult).withOpacity(0.2),
                                child: Icon(
                                  record.scanResult == 'VALID' ? Icons.check : Icons.close,
                                  color: _getResultColor(record.scanResult),
                                ),
                              ),
                              title: Text(
                                record.ticketPublicId,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              subtitle: Text('${record.scanResult} • $date $time'),
                              trailing: record.isSynced 
                                  ? const Icon(Icons.cloud_done, color: Colors.green, size: 20)
                                  : const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
