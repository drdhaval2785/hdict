import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('headword color default and setter', () async {
    final provider = SettingsProvider();

    // constructor loads settings asynchronously; give it a moment
    await Future.delayed(Duration(milliseconds: 100));

    expect(provider.headwordColor.toARGB32(), equals(Colors.brown.toARGB32()));

    await provider.setHeadwordColor(Colors.red);
    expect(provider.headwordColor.toARGB32(), equals(Colors.red.toARGB32()));

    // simulate new provider to verify persistence
    final provider2 = SettingsProvider();
    await Future.delayed(Duration(milliseconds: 100));
    expect(provider2.headwordColor.toARGB32(), equals(Colors.red.toARGB32()));
  });

  test('listMode default is false', () async {
    final provider = SettingsProvider();
    await Future.delayed(Duration(milliseconds: 100));
    expect(provider.isListModeEnabled, false);
  });

  test('listMode persists after toggle', () async {
    final provider = SettingsProvider();
    await Future.delayed(Duration(milliseconds: 100));

    await provider.setListMode(true);
    expect(provider.isListModeEnabled, true);

    // Verify persistence
    final provider2 = SettingsProvider();
    await Future.delayed(Duration(milliseconds: 100));
    expect(provider2.isListModeEnabled, true);
  });

  test('listMode can be toggled off', () async {
    final provider = SettingsProvider();
    await Future.delayed(Duration(milliseconds: 100));

    await provider.setListMode(true);
    expect(provider.isListModeEnabled, true);

    await provider.setListMode(false);
    expect(provider.isListModeEnabled, false);
  });
}
