import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  String dbPath = '/Users/dhaval/Documents/FlutterProjects/hdict/novalex.db'; // Assuming standard location
  
  if (!File(dbPath).existsSync()) {
    print("DB not found at \$dbPath");
    return;
  }
  
  var db = await dbFactory.openDatabase(dbPath);
  
  // Test LIKE query
  var watch1 = Stopwatch()..start();
  var res1 = await db.rawQuery('SELECT COUNT(*) FROM word_index WHERE content LIKE ?', ['%beautiful%']);
  watch1.stop();
  print('LIKE query took \${watch1.elapsedMilliseconds}ms. Count: \${res1.first.values.first}');
  
  // Test MATCH query
  var watch2 = Stopwatch()..start();
  var res2 = await db.rawQuery('SELECT COUNT(*) FROM word_index WHERE content MATCH ?', ['beautiful']);
  watch2.stop();
  print('MATCH query took \${watch2.elapsedMilliseconds}ms. Count: \${res2.first.values.first}');
  
  // Test MATCH prefix query
  var watch3 = Stopwatch()..start();
  var res3 = await db.rawQuery('SELECT COUNT(*) FROM word_index WHERE content MATCH ?', ['beauti*']);
  watch3.stop();
  print('MATCH prefix query took \${watch3.elapsedMilliseconds}ms. Count: \${res3.first.values.first}');

  await db.close();
}
