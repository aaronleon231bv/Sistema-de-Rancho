import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart' show OpenDatabaseOptions;

import 'ranch_store.dart';

Future<RanchStore> openRanchStore({
  String? accountId,
  RanchRemote? remote,
}) async {
  final db = await databaseFactoryFfiWeb.openDatabase(
    accountId == null ? 'rancho.db' : 'rancho_$accountId.db',
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: RanchStore.createSchema,
      onUpgrade: RanchStore.upgradeSchema,
    ),
  );
  return RanchStore(db, remote: remote);
}
