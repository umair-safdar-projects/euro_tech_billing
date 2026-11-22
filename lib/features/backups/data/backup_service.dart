import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/schema.dart';
import '../domain/backup_models.dart';

class BackupService {
  BackupService(this._appDatabase, {String? defaultDirectory})
    : _configuredDefaultDirectory = defaultDirectory;

  static const _destinationKey = 'backup.destination';
  static const _lastSuccessKey = 'backup.last_success_at';

  final AppDatabase _appDatabase;
  final String? _configuredDefaultDirectory;

  Future<String> destination() async {
    final rows = await _appDatabase.database.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_destinationKey],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['value']! as String;
    if (_configuredDefaultDirectory != null) {
      return _configuredDefaultDirectory;
    }
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, 'Euro Tech Billing Backups');
  }

  Future<void> setDestination(String path) async {
    final clean = path.trim();
    if (clean.isEmpty) throw const FormatException('Choose a backup folder.');
    final directory = Directory(clean);
    await directory.create(recursive: true);
    final probe = File(p.join(clean, '.euro-tech-write-test'));
    try {
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } on FileSystemException catch (error) {
      throw BackupException(
        'The selected backup folder is not writable.',
        technicalDetails: error.toString(),
      );
    }
    await _writeSetting(_destinationKey, clean);
  }

  Future<BackupMetadata> createBackup({String type = 'manual'}) async {
    if (!const ['manual', 'automatic', 'safety'].contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
    final directory = Directory(await destination());
    try {
      await directory.create(recursive: true);
      final output = await _uniqueBackupFile(directory, type);
      await _appDatabase.database.execute(
        "VACUUM INTO '${_quote(output.path)}'",
      );
      final metadata = await verify(output.path);
      final now = DateTime.now().toUtc();
      await _appDatabase.database.insert('backup_history', {
        'file_path': output.path,
        'created_at': now.toIso8601String(),
        'file_size': metadata.fileSize,
        'backup_type': type,
        'integrity_status': 'ok',
      });
      await _writeSetting(_lastSuccessKey, now.toIso8601String());
      return metadata;
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(
        'The database backup could not be created. Check the destination and available disk space.',
        technicalDetails: error.toString(),
      );
    }
  }

  Future<BackupMetadata?> runAutomaticBackupIfDue() async {
    final status = await loadStatus();
    final last = status.lastSuccessfulAt;
    if (last != null && DateTime.now().difference(last).inHours < 24) {
      return null;
    }
    return createBackup(type: 'automatic');
  }

  Future<BackupMetadata> verify(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const BackupException('The selected backup file does not exist.');
    }
    Database? database;
    try {
      database = await _appDatabase.factory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const BackupException(
          'The selected file failed SQLite integrity verification.',
        );
      }
      final versionRows = await database.rawQuery('PRAGMA user_version');
      final version = versionRows.first.values.first! as int;
      if (version < 1 || version > DatabaseSchema.currentVersion) {
        throw BackupException(
          version > DatabaseSchema.currentVersion
              ? 'This backup was created by a newer application version.'
              : 'The selected file is not a supported Euro Tech backup.',
        );
      }
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      for (final required in ['invoices', 'customers', 'payments']) {
        if (!names.contains(required)) {
          throw const BackupException(
            'The selected file is not a valid Euro Tech billing database.',
          );
        }
      }
      return BackupMetadata(
        path: file.absolute.path,
        createdAt: (await file.lastModified()).toLocal(),
        fileSize: await file.length(),
        schemaVersion: version,
        invoiceCount: await _count(database, 'invoices'),
        customerCount: await _count(database, 'customers'),
        paymentCount: await _count(database, 'payments'),
      );
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(
        'The selected file is not a readable SQLite backup.',
        technicalDetails: error.toString(),
      );
    } finally {
      await database?.close();
    }
  }

  Future<BackupMetadata> restore(String sourcePath) async {
    final selected = await verify(sourcePath);
    final preservedDestination = await destination();
    final safety = await createBackup(type: 'safety');
    final databasePath = _appDatabase.databasePath;
    final databaseFile = File(databasePath);
    final token = DateTime.now().microsecondsSinceEpoch;
    final rollback = File('$databasePath.pre-restore-$token');
    final staging = File('$databasePath.restore-$token');
    var connectionClosed = false;
    var databaseSwapped = false;
    try {
      await File(sourcePath).copy(staging.path);
      await _appDatabase.close();
      connectionClosed = true;
      if (await databaseFile.exists()) {
        await databaseFile.rename(rollback.path);
        databaseSwapped = true;
      }
      await _deleteSidecars(databasePath);
      await staging.copy(databasePath);
      await staging.delete();
      await _appDatabase.initialize();
      final check = await _appDatabase.database.rawQuery(
        'PRAGMA integrity_check',
      );
      if (check.isEmpty || check.first.values.first != 'ok') {
        throw const BackupException(
          'The restored database failed its final integrity check.',
        );
      }
      await setDestination(preservedDestination);
      final restoredAt = DateTime.now().toUtc();
      await _appDatabase.database.insert('backup_history', {
        'file_path': safety.path,
        'created_at': restoredAt.toIso8601String(),
        'file_size': safety.fileSize,
        'backup_type': 'safety',
        'integrity_status': 'ok',
      });
      await _writeSetting(_lastSuccessKey, restoredAt.toIso8601String());
      if (await rollback.exists()) await rollback.delete();
      return selected;
    } catch (error) {
      try {
        if (databaseSwapped) {
          await _appDatabase.close();
          if (await databaseFile.exists()) await databaseFile.delete();
          if (await rollback.exists()) await rollback.rename(databasePath);
        }
        if (await staging.exists()) await staging.delete();
        if (connectionClosed) await _appDatabase.initialize();
      } catch (_) {
        // The external safety backup is retained for manual recovery.
      }
      throw BackupException(
        'Restore failed. The original database was recovered; the safety backup is ${safety.path}.',
        technicalDetails: error.toString(),
      );
    }
  }

  Future<BackupStatus> loadStatus() async {
    final settingRows = await _appDatabase.database.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_lastSuccessKey],
      limit: 1,
    );
    final historyRows = await _appDatabase.database.query(
      'backup_history',
      orderBy: 'created_at DESC',
      limit: 10,
    );
    return BackupStatus(
      destination: await destination(),
      lastSuccessfulAt: settingRows.isEmpty
          ? null
          : DateTime.tryParse(
              settingRows.single['value']! as String,
            )?.toLocal(),
      history: historyRows
          .map(
            (row) => BackupHistoryEntry(
              path: row['file_path']! as String,
              createdAt: DateTime.parse(row['created_at']! as String).toLocal(),
              fileSize: row['file_size']! as int,
              type: row['backup_type']! as String,
              integrityStatus: row['integrity_status']! as String,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _writeSetting(String key, String value) async {
    await _appDatabase.database.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<File> _uniqueBackupFile(Directory directory, String type) async {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    for (var suffix = 0; suffix < 1000; suffix++) {
      final extra = suffix == 0 ? '' : '-$suffix';
      final file = File(
        p.join(directory.path, 'euro-tech-$type-$stamp$extra.sqlite'),
      );
      if (!await file.exists()) return file;
    }
    throw const BackupException(
      'A unique backup filename could not be created.',
    );
  }

  Future<int> _count(Database database, String table) async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM $table',
    );
    return rows.single['count']! as int;
  }

  Future<void> _deleteSidecars(String path) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$path$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  String _quote(String value) => value.replaceAll("'", "''");
}
