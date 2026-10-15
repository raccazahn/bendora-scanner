import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ticket_model.dart';
import '../models/scan_record_model.dart';
import '../models/event_pack_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'bendora_scanner.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE event_pack (
        version INTEGER PRIMARY KEY,
        event_id INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        gate_id INTEGER,
        gate_name TEXT,
        public_key TEXT NOT NULL,
        generated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tickets (
        public_ticket_id TEXT PRIMARY KEY,
        ticket_type TEXT NOT NULL,
        gate_id INTEGER,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE scan_records (
        local_scan_id TEXT PRIMARY KEY,
        ticket_public_id TEXT NOT NULL,
        event_id INTEGER NOT NULL,
        gate_id INTEGER,
        scan_result TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('CREATE INDEX idx_ticket_public_id ON tickets(public_ticket_id)');
    await db.execute('CREATE INDEX idx_scan_synced ON scan_records(is_synced)');
  }

  Future<void> saveEventPackTransactionally(EventPackModel pack) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tickets');
      await txn.delete('event_pack');
      await txn.insert('event_pack', pack.toMap());

      final batch = txn.batch();
      for (final ticket in pack.tickets) {
        batch.insert('tickets', ticket.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<EventPackModel?> getEventPack() async {
    final db = await database;
    final packMaps = await db.query('event_pack', limit: 1);
    if (packMaps.isEmpty) return null;

    final packMap = packMaps.first;
    final ticketMaps = await db.query('tickets');
    final tickets = ticketMaps.map((e) => TicketModel.fromMap(e)).toList();

    return EventPackModel.fromMap(packMap, tickets);
  }

  Future<int> getCurrentPackVersion() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(version) as max_version FROM event_pack');
    return (result.first['max_version'] as int?) ?? 0;
  }

  Future<TicketModel?> getTicket(String publicTicketId) async {
    final db = await database;
    final maps = await db.query(
      'tickets',
      where: 'public_ticket_id = ?',
      whereArgs: [publicTicketId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TicketModel.fromMap(maps.first);
  }

  Future<bool> hasLocalScan(String localScanId) async {
    final db = await database;
    final result = await db.query(
      'scan_records',
      columns: ['local_scan_id'],
      where: 'local_scan_id = ?',
      whereArgs: [localScanId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> insertScanRecord(ScanRecordModel record) async {
    final db = await database;
    await db.insert(
      'scan_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScanRecordModel>> getUnsyncedScans() async {
    final db = await database;
    final maps = await db.query(
      'scan_records',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'scanned_at ASC',
    );
    return maps.map((e) => ScanRecordModel.fromMap(e)).toList();
  }

  Future<void> markScanAsSynced(String localScanId) async {
    final db = await database;
    await db.update(
      'scan_records',
      {'is_synced': 1},
      where: 'local_scan_id = ?',
      whereArgs: [localScanId],
    );
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('tickets');
    await db.delete('event_pack');
    await db.delete('scan_records');
  }
}
