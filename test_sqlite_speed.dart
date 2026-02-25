import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  
  // The DB is typically at ~/Documents/novalex.db based on DatabaseHelper
  String dbPath = '${Platform.environment['HOME']}/Documents/novalex.db'; 
  
  if (!File(dbPath).existsSync()) {
    print("DB not found at $dbPath");
    return;
  }
  
  var db = await dbFactory.openDatabase(dbPath);
  
  print("Testing LIKE...");
  var watch1 = Stopwatch()..start();
  var res1 = await db.rawQuery('SELECT COUNT(*) FROM word_index WHERE content LIKE ?', ['%sanskrit%']);
  watch1.stop();
  print('LIKE query took ${watch1.elapsedMilliseconds}ms. Count: ${res1.first.values.first}');
  
  print("Testing MATCH exact...");
  var watch2 = Stopwatch()..start();
  var res2 = await db.rawQuery('SELECT COUNT(*) FROM word_index WHERE content MATCH ?', ['sanskrit']);
  watch2.stop();
  print('MATCH query took ${watch2.elapsedMilliseconds}ms. Count: ${res2.first.values.first}');
  
  print("Testing MATCH prefix...");
  var watch3 = Stopwatch()..start();
  var res3 = await db.rawQuery('SELECT COUNT(*) FROM word_index WHERE content MATCH ?', ['sanskr*']);
  watch3.stop();
  print('MATCH prefix query took ${watch3.elapsedMilliseconds}ms. Count: ${res3.first.values.first}');

  await db.close();
}
