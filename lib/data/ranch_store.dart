import 'dart:convert';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

enum RecordKind { parcel, crop, practice, observation }

class RanchRecord {
  const RanchRecord({
    required this.id,
    required this.kind,
    required this.fields,
    required this.revision,
    required this.pending,
    this.baseRevision = 0,
  });
  final String id;
  final RecordKind kind;
  final Map<String, dynamic> fields;
  final int revision;
  final bool pending;
  final int baseRevision;
  String get title => fields['name'] as String? ?? '';
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'fields': fields,
    'revision': revision,
  };
  factory RanchRecord.fromRow(Map<String, Object?> row) => RanchRecord(
    id: row['id'] as String,
    kind: RecordKind.values.byName(row['kind'] as String),
    fields: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    revision: row['revision'] as int,
    pending: row['pending'] == 1,
    baseRevision: row['base_revision'] as int? ?? 0,
  );
}

abstract class RanchRemote {
  Future<void> send(RanchRecord record);
  Future<List<RanchRecord>> download();
}

/// All edits commit locally before they become eligible for upload.
class RanchStore {
  RanchStore(this.db, {http.Client? client, this.remote})
    : client = client ?? http.Client();
  final RanchRemote? remote;
  final Database db;
  final http.Client client;
  bool _syncing = false;

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE records (id TEXT PRIMARY KEY, kind TEXT NOT NULL, '
      'payload TEXT NOT NULL, revision INTEGER NOT NULL, pending INTEGER NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE records ADD COLUMN base_revision INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<List<RanchRecord>> records() async => (await db.query(
    'records',
    orderBy: 'rowid DESC',
  )).map(RanchRecord.fromRow).toList();

  Future<void> save(
    RecordKind kind,
    Map<String, dynamic> fields, {
    String? id,
  }) async {
    await db.transaction((txn) async {
      final recordId = id ?? const Uuid().v4();
      final previous = await txn.query(
        'records',
        where: 'id = ?',
        whereArgs: [recordId],
      );
      final revision = previous.isEmpty
          ? 1
          : (previous.first['revision'] as int) + 1;
      await txn.insert('records', {
        'id': recordId,
        'kind': kind.name,
        'payload': jsonEncode(fields),
        'revision': revision,
        'pending': 1,
        'base_revision': previous.isEmpty
            ? 0
            : previous.first['base_revision'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Delete only the saved practice the user reviewed, never a newer edit.
  Future<void> deletePractice(RanchRecord record) async {
    if (record.kind != RecordKind.practice) {
      throw ArgumentError('Solo se pueden eliminar prácticas con esta acción.');
    }
    final deleted = await db.delete(
      'records',
      where: 'id = ? AND kind = ? AND revision = ?',
      whereArgs: [record.id, RecordKind.practice.name, record.revision],
    );
    if (deleted != 1) {
      throw StateError(
        'La práctica cambió o ya no existe. Vuelve a abrirla antes de eliminarla.',
      );
    }
  }

  /// Read the committed database instead of a potentially stale screen cache.
  Future<String> exportBackup() async =>
      const JsonEncoder.withIndent('  ').convert({
        'format': 'bitacora-rancho',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'records': (await records()).map((r) => r.toJson()).toList(),
      });

  /// Validates every row and relationship before making any changes.
  /// Existing IDs are retained, so importing twice never duplicates records.
  Future<({int imported, int skipped})> restoreBackup(String content) async {
    final List<RanchRecord> incoming;
    try {
      final root = jsonDecode(
        content.startsWith('\uFEFF') ? content.substring(1) : content,
      );
      if (root is! Map ||
          root['records'] is! List ||
          (root['format'] != null && root['format'] != 'bitacora-rancho') ||
          (root['version'] != null && root['version'] != 1)) {
        throw const FormatException();
      }
      final ids = <String>{};
      incoming = (root['records'] as List).map((value) {
        if (value is! Map ||
            value['id'] is! String ||
            (value['id'] as String).trim().isEmpty ||
            !ids.add(value['id'] as String) ||
            value['kind'] is! String ||
            value['fields'] is! Map ||
            value['revision'] is! int ||
            (value['revision'] as int) < 1) {
          throw const FormatException();
        }
        final kind = RecordKind.values.byName(value['kind'] as String);
        final fields = Map<String, dynamic>.from(value['fields'] as Map);
        _validateBackupFields(kind, fields);
        return RanchRecord(
          id: value['id'] as String,
          kind: kind,
          fields: fields,
          revision: value['revision'] as int,
          pending: true,
        );
      }).toList();
    } catch (_) {
      throw const FormatException(
        'El archivo no es un respaldo válido. No se importó ningún registro.',
      );
    }
    for (final record in incoming) {
      final photo = record.fields['photo'];
      if (photo == null) continue;
      try {
        final codec = await ui.instantiateImageCodec(
          base64Decode(photo['base64'] as String),
          targetWidth: 160,
          allowUpscaling: false,
        );
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } catch (_) {
        throw const FormatException(
          'El respaldo contiene una fotografía inválida. No se importó ningún registro.',
        );
      }
    }
    return db.transaction((txn) async {
      final existing = (await txn.query(
        'records',
      )).map(RanchRecord.fromRow).toList();
      final byId = {for (final r in existing) r.id: r};
      final additions = incoming.where((r) => !byId.containsKey(r.id)).toList();
      byId.addAll({for (final r in additions) r.id: r});
      for (final record in additions) {
        final f = record.fields;
        if (record.kind == RecordKind.parcel) continue;
        final parcel = byId[f['parcelId']];
        final crop = byId[f['cropId']];
        if (parcel?.kind != RecordKind.parcel ||
            (f['cropId'] != null &&
                (crop?.kind != RecordKind.crop ||
                    crop?.fields['parcelId'] != parcel!.id))) {
          throw const FormatException(
            'El respaldo contiene vínculos inválidos entre parcelas y cultivos. No se importó ningún registro.',
          );
        }
      }
      for (final record in additions) {
        await txn.insert('records', {
          'id': record.id,
          'kind': record.kind.name,
          'payload': jsonEncode(record.fields),
          'revision': record.revision,
          'pending': 1,
          'base_revision': 0,
        });
      }
      return (
        imported: additions.length,
        skipped: incoming.length - additions.length,
      );
    });
  }

  static void _validateBackupFields(RecordKind kind, Map<String, dynamic> f) {
    void text(String key, {bool required = false}) {
      final value = f[key];
      if ((value != null && value is! String) ||
          (required && (value is! String || value.trim().isEmpty))) {
        throw const FormatException();
      }
    }

    text('name', required: true);
    for (final key in [
      'notes',
      'location',
      'variety',
      'responsible',
      'activity',
      'stage',
      'severity',
      'followUp',
      'cycle',
      'inputName',
      'inputUnit',
    ]) {
      text(key);
    }
    for (final key in [
      'inputQuantity',
      'inputCost',
      'laborHours',
      'hourlyCost',
      'otherCost',
      'harvestKg',
      'harvestArea',
    ]) {
      final value = f[key];
      if (value != null &&
          (value is! num ||
              !value.isFinite ||
              value < 0 ||
              (['inputQuantity', 'harvestKg', 'harvestArea'].contains(key) &&
                  value == 0))) {
        throw const FormatException();
      }
    }
    final history = f['followUpHistory'];
    if (history != null) {
      if (kind != RecordKind.observation || history is! List) {
        throw const FormatException();
      }
      for (final entry in history) {
        if (entry is! Map ||
            entry['date'] is! String ||
            DateTime.tryParse(entry['date'] as String) == null ||
            !['Abierta', 'En atención', 'Resuelta'].contains(entry['status']) ||
            entry['notes'] is! String ||
            entry['responsible'] is! String) {
          throw const FormatException();
        }
      }
    }
    if (kind == RecordKind.parcel) {
      final area = f['area'];
      if (area is! num || !area.isFinite || area <= 0) {
        throw const FormatException();
      }
    } else {
      text('parcelId', required: true);
      text('cropId');
      text('date', required: true);
      final date = f['date'] as String;
      final parsed = DateTime.tryParse(date);
      if (parsed == null ||
          parsed.toIso8601String().substring(0, 10) != date ||
          parsed.year < 2000 ||
          parsed.year > 2200) {
        throw const FormatException();
      }
    }
    if (f['status'] != null) {
      final options = kind == RecordKind.practice
          ? ['Pendiente', 'Realizada']
          : ['Abierta', 'En atención', 'Resuelta'];
      if (!options.contains(f['status'])) throw const FormatException();
    }
    final photo = f['photo'];
    if (photo != null) {
      if (kind != RecordKind.observation ||
          photo is! Map ||
          photo['name'] is! String ||
          photo['base64'] is! String) {
        throw const FormatException();
      }
      final bytes = base64Decode(photo['base64'] as String);
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw const FormatException();
      }
    }
  }

  Future<int> verifySavedRecords() async {
    final check = await db.rawQuery('PRAGMA integrity_check');
    if (check.length != 1 || check.single.values.single != 'ok') {
      throw StateError('No se pudo comprobar la integridad de la bitácora.');
    }
    return (await records()).length;
  }

  Future<String> endpoint() async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['endpoint'],
    );
    return rows.isEmpty ? '' : rows.first['value'] as String;
  }

  Future<void> setEndpoint(String value) async {
    await db.transaction((txn) async {
      final previous = await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['endpoint'],
      );
      if (previous.isNotEmpty && previous.first['value'] == value) return;
      await txn.insert('settings', {
        'key': 'endpoint',
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // Increment versions so an old in-flight upload cannot clear this queue.
      await txn.rawUpdate(
        'UPDATE records SET pending = 1, revision = revision + 1',
      );
    });
  }

  Future<int> synchronize() async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      if (remote != null) return await _synchronizeRemote();
      final address = await endpoint();
      if (address.isEmpty) {
        throw StateError('Configura el servidor para sincronizar.');
      }
      final pending = (await records()).where((r) => r.pending).toList();
      if (pending.isEmpty) return 0;
      final response = await client
          .post(
            Uri.parse(address),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'records': pending.map((r) => r.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('El servidor respondió ${response.statusCode}.');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final accepted = body['accepted'] as List<dynamic>;
      int count = 0;
      await db.transaction((txn) async {
        for (final record in pending) {
          final acknowledged = accepted.any(
            (a) =>
                a is Map &&
                a['id'] == record.id &&
                a['revision'] == record.revision,
          );
          if (acknowledged) {
            // An edit made during upload must stay pending.
            count += await txn.update(
              'records',
              {'pending': 0},
              where: 'id = ? AND revision = ?',
              whereArgs: [record.id, record.revision],
            );
          }
        }
      });
      return count;
    } finally {
      _syncing = false;
    }
  }

  Future<int> _synchronizeRemote() async {
    final pending = (await records()).where((r) => r.pending).toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    var count = 0;
    for (final record in pending) {
      await remote!.send(record);
      await db.transaction((txn) async {
        // Acknowledged data becomes the base for any edit made during upload.
        await txn.update(
          'records',
          {'base_revision': record.revision},
          where: 'id = ? AND base_revision <= ?',
          whereArgs: [record.id, record.revision],
        );
        count += await txn.update(
          'records',
          {'pending': 0},
          where: 'id = ? AND revision = ?',
          whereArgs: [record.id, record.revision],
        );
      });
    }
    final downloaded = await remote!.download();
    await db.transaction((txn) async {
      for (final record in downloaded) {
        final existing = await txn.query(
          'records',
          where: 'id = ?',
          whereArgs: [record.id],
        );
        if (existing.isNotEmpty &&
            (existing.first['pending'] == 1 ||
                (existing.first['revision'] as int) > record.revision)) {
          continue;
        }
        await txn.insert('records', {
          'id': record.id,
          'kind': record.kind.name,
          'payload': jsonEncode(record.fields),
          'revision': record.revision,
          'pending': 0,
          'base_revision': record.revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return count;
  }

  Future<void> close() async {
    client.close();
    await db.close();
  }
}
