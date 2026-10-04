import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ranch_store.dart';

Future<RanchStore> openRanchStore({
  String? accountId,
  RanchRemote? remote,
}) async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final db = await openDatabase(
    p.join(
      directory.path,
      accountId == null ? 'rancho.db' : 'rancho_$accountId.db',
    ),
    version: 2,
    onCreate: RanchStore.createSchema,
    onUpgrade: RanchStore.upgradeSchema,
  );
  return RanchStore(db, remote: remote);
}
