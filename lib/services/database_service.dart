import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/models.dart';

/// SQLite 持久化层，数据文件位于 %APPDATA%/Statis/statis.db。
class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    sqfliteFfiInit();
    final appData = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    final dir = Directory(p.join(appData, 'Statis'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return databaseFactoryFfi.openDatabase(
      p.join(dir.path, 'statis.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              ai_enabled INTEGER NOT NULL DEFAULT 1,
              keywords TEXT NOT NULL DEFAULT '',
              last_summary_at INTEGER,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_id INTEGER NOT NULL,
              occurred_at INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_records_event ON records(event_id, occurred_at)',
          );
        },
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  // ---- events ----

  Future<List<Event>> loadEvents() async {
    final db = await database;
    final rows = await db.query('events', orderBy: 'created_at DESC');
    return rows.map(Event.fromMap).toList();
  }

  Future<int> insertEvent(Event event) async {
    final db = await database;
    return db.insert('events', event.toMap());
  }

  Future<void> updateEvent(Event event) async {
    final db = await database;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  /// 删除事件并级联删除其全部记录。
  Future<void> deleteEvent(int eventId) async {
    final db = await database;
    await db.delete('records', where: 'event_id = ?', whereArgs: [eventId]);
    await db.delete('events', where: 'id = ?', whereArgs: [eventId]);
  }

  Future<void> markSummarized(int eventId, DateTime at) async {
    final db = await database;
    await db.update(
      'events',
      {'last_summary_at': at.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  // ---- records ----

  Future<List<EventRecord>> loadAllRecords() async {
    final db = await database;
    final rows = await db.query('records', orderBy: 'occurred_at DESC');
    return rows.map(EventRecord.fromMap).toList();
  }

  Future<int> insertRecord(EventRecord record) async {
    final db = await database;
    return db.insert('records', record.toMap());
  }

  Future<void> deleteRecord(int recordId) async {
    final db = await database;
    await db.delete('records', where: 'id = ?', whereArgs: [recordId]);
  }
}
