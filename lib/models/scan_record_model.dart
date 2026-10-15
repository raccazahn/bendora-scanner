class ScanRecordModel {
  final String localScanId;
  final String ticketPublicId;
  final int eventId;
  final int? gateId;
  final String scanResult;
  final DateTime scannedAt;
  final bool isSynced;

  ScanRecordModel({
    required this.localScanId,
    required this.ticketPublicId,
    required this.eventId,
    this.gateId,
    required this.scanResult,
    required this.scannedAt,
    this.isSynced = false,
  });

  factory ScanRecordModel.fromMap(Map<String, dynamic> map) {
    return ScanRecordModel(
      localScanId: map['local_scan_id'] as String,
      ticketPublicId: map['ticket_public_id'] as String,
      eventId: map['event_id'] as int,
      gateId: map['gate_id'] as int?,
      scanResult: map['scan_result'] as String,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_scan_id': localScanId,
      'ticket_public_id': ticketPublicId,
      'event_id': eventId,
      'gate_id': gateId,
      'scan_result': scanResult,
      'scanned_at': scannedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
