import 'package:sqflite_common_ffi/sqflite_ffi.dart';
void main() async {
  sqfliteFfiInit();
  var db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE foo (id INTEGER, val TEXT);
    INSERT INTO foo VALUES (1, 'A'), (1, 'B'), (2, 'C'), (2, 'a');
  ''');
  var res = await db.rawQuery('''
    SELECT val, id FROM (
      SELECT * FROM (SELECT val, id, 1 as sort_order FROM foo WHERE id = 1 ORDER BY val ASC LIMIT 2)
      UNION ALL
      SELECT * FROM (SELECT val, id, 2 as sort_order FROM foo WHERE id = 2 ORDER BY val ASC LIMIT 2)
    ) ORDER BY sort_order ASC, val ASC LIMIT 3
  ''');
  print(res);
}
