import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/scan_record_model.dart';
import '../models/event_pack_model.dart';
import '../models/ticket_model.dart';
import 'database_service.dart';
import 'crypto_service.dart';

enum ScanResultType {
  valid,
  alreadyUsed,
  wrongEvent,
  wrongGate,
  invalidSignature,
  expired,
  unknownTicket,
  revoked,
  cancelled,
  replaced,
  invalidFormat,
}

class ScanResult {
  final ScanResultType type;
  final String message;
  final TicketModel? ticket;

  ScanResult({required this.type, required this.message, this.ticket});
}

class ScannerService {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  Future<ScanResult> processScan(
    String qrData, 
    EventPackModel pack, 
    int? assignedGateId
  ) async {
    final localScanId = _uuid.v4();
    final scannedAt = DateTime.now();

    try {
      // 1. Decode JSON
      final Map<String, dynamic> payload;
      try {
        payload = jsonDecode(qrData);
      } catch (e) {
        await _saveRecord(localScanId, 'UNKNOWN', pack.eventId, assignedGateId, ScanResultType.invalidFormat, scannedAt);
        return ScanResult(type: ScanResultType.invalidFormat, message: 'Invalid QR Format');
      }

      // 2. Verify Signature
      final signatureB64 = payload['sig'];
      if (signatureB64 == null) {
        await _saveRecord(localScanId, payload['tid'] ?? 'UNKNOWN', pack.eventId, assignedGateId, ScanResultType.invalidSignature, scannedAt);
        return ScanResult(type: ScanResultType.invalidSignature, message: 'Missing Signature');
      }

      // Reconstruct payload without 'sig' for verification (sorted keys for deterministic JSON)
      final payloadForSigning = Map<String, dynamic>.from(payload);
      payloadForSigning.remove('sig');
      
      final sortedJson = jsonEncode(_sortMapKeys(payloadForSigning));
      final signatureBytes = base64Url.decode(signatureB64);

      final isValidSig = await CryptoService.verifySignature(
        sortedJson,
        signatureBytes,
        pack.publicKey,
      );

      if (!isValidSig) {
        await _saveRecord(localScanId, payload['tid'] ?? 'UNKNOWN', pack.eventId, assignedGateId, ScanResultType.invalidSignature, scannedAt);
        return ScanResult(type: ScanResultType.invalidSignature, message: 'Invalid Signature');
      }

      // 3. Check Event
      final ticketEventId = payload['eid'];
      if (ticketEventId != pack.eventId) {
        await _saveRecord(localScanId, payload['tid'] ?? 'UNKNOWN', pack.eventId, assignedGateId, ScanResultType.wrongEvent, scannedAt);
        return ScanResult(type: ScanResultType.wrongEvent, message: 'Wrong Event');
      }

      // 4. Check Gate
      final ticketGateId = payload['gid'];
      if (assignedGateId != null && ticketGateId != null && ticketGateId != assignedGateId) {
        await _saveRecord(localScanId, payload['tid'] ?? 'UNKNOWN', pack.eventId, assignedGateId, ScanResultType.wrongGate, scannedAt);
        return ScanResult(type: ScanResultType.wrongGate, message: 'Wrong Gate');
      }

      // 5. Check Expiry
      final exp = payload['exp'];
      if (exp != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expiryDate)) {
          await _saveRecord(localScanId, payload['tid'] ?? 'UNKNOWN', pack.eventId, assignedGateId, ScanResultType.expired, scannedAt);
          return ScanResult(type: ScanResultType.expired, message: 'Expired Ticket');
        }
      }

      // 6. Check Local DB for Ticket Existence & Status
      final ticketId = payload['tid'] as String;
      final ticket = await _db.getTicket(ticketId);
      
      if (ticket == null) {
        await _saveRecord(localScanId, ticketId, pack.eventId, assignedGateId, ScanResultType.unknownTicket, scannedAt);
        return ScanResult(type: ScanResultType.unknownTicket, message: 'Unknown Ticket');
      }

      if (ticket.status == 'REVOKED' || ticket.status == 'CANCELLED') {
         final type = ticket.status == 'REVOKED' ? ScanResultType.revoked : ScanResultType.cancelled;
         await _saveRecord(localScanId, ticketId, pack.eventId, assignedGateId, type, scannedAt);
         return ScanResult(type: type, message: 'Ticket ${ticket.status}');
      }

      // 7. Check Local Duplicate (Already Used locally)
      // We use a deterministic local ID based on ticket ID to prevent duplicate local scans
      final deterministicLocalId = 'valid_$ticketId';
      final hasLocalValidScan = await _db.hasLocalScan(deterministicLocalId);
      
      if (hasLocalValidScan) {
        await _saveRecord(localScanId, ticketId, pack.eventId, assignedGateId, ScanResultType.alreadyUsed, scannedAt);
        return ScanResult(type: ScanResultType.alreadyUsed, message: 'Already Used');
      }

      // 8. VALID - Save the successful scan locally to prevent future duplicates
      await _saveRecord(deterministicLocalId, ticketId, pack.eventId, assignedGateId, ScanResultType.valid, scannedAt);
      
      return ScanResult(type: ScanResultType.valid, message: 'Valid Ticket', ticket: ticket);

    } catch (e) {
      print('Scan processing error: $e');
      await _saveRecord(localScanId, 'ERROR', pack.eventId, assignedGateId, ScanResultType.invalidFormat, scannedAt);
      return ScanResult(type: ScanResultType.invalidFormat, message: 'Processing Error');
    }
  }

  Future<void> _saveRecord(
    String localScanId,
    String ticketId,
    int eventId,
    int? gateId,
    ScanResultType resultType,
    DateTime scannedAt,
  ) async {
    final record = ScanRecordModel(
      localScanId: localScanId,
      ticketPublicId: ticketId,
      eventId: eventId,
      gateId: gateId,
      scanResult: resultType.name.toUpperCase(),
      scannedAt: scannedAt,
      isSynced: false,
    );
    await _db.insertScanRecord(record);
  }

  Map<String, dynamic> _sortMapKeys(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedMap[key] = map[key];
    }
    return sortedMap;
  }
}
