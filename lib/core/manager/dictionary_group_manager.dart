import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';

class DictionaryGroup {
  final String id;
  final String name;
  final List<int> dictIds;

  DictionaryGroup({
    required this.id,
    required this.name,
    required this.dictIds,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dictIds': dictIds,
  };

  factory DictionaryGroup.fromJson(Map<String, dynamic> json) => DictionaryGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    dictIds: List<int>.from(json['dictIds'] ?? []),
  );
}

class DictionaryGroupManager {
  static const String _key = 'dictionary_groups';
  
  static Future<List<DictionaryGroup>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((j) => DictionaryGroup.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> saveGroups(List<DictionaryGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(groups.map((g) => g.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static Future<void> addDictionaryToGroup(String groupName, int dictId) async {
    final groups = await getGroups();
    final groupId = groupName.toLowerCase().replaceAll(' ', '_');
    
    int extIndex = groups.indexWhere((g) => g.id == groupId);
    if (extIndex >= 0) {
      if (!groups[extIndex].dictIds.contains(dictId)) {
        groups[extIndex].dictIds.add(dictId);
      }
    } else {
      groups.add(DictionaryGroup(id: groupId, name: groupName, dictIds: [dictId]));
    }
    await saveGroups(groups);
  }

  static Future<void> removeDictionaryFromGroup(String groupId, int dictId) async {
    final groups = await getGroups();
    int extIndex = groups.indexWhere((g) => g.id == groupId);
    if (extIndex >= 0) {
      groups[extIndex].dictIds.remove(dictId);
      await saveGroups(groups);
    }
  }

  static Future<void> deleteGroup(String groupId) async {
     final groups = await getGroups();
     groups.removeWhere((g) => g.id == groupId);
     await saveGroups(groups);
  }

  static Future<void> createCustomGroup(String groupName) async {
     final groups = await getGroups();
     final groupId = groupName.toLowerCase().replaceAll(' ', '_');
     if (!groups.any((g) => g.id == groupId)) {
       groups.add(DictionaryGroup(id: groupId, name: groupName, dictIds: []));
       await saveGroups(groups);
     }
  }

  static Future<void> toggleGroup(String groupId, bool enable) async {
    final groups = await getGroups();
    final group = groups.firstWhere((g) => g.id == groupId);
    final DictionaryManager dictManager = DictionaryManager();
    for(int dictId in group.dictIds) {
      await dictManager.toggleDictionaryEnabled(dictId, enable);
    }
  }
  
  static Future<bool> isGroupActive(String groupId) async {
    final groups = await getGroups();
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return false;
    final group = groups[idx];
    if (group.dictIds.isEmpty) return false;
    final DictionaryManager dictManager = DictionaryManager();
    final activeDicts = await dictManager.getDictionaries();
    for (int dictId in group.dictIds) {
      final ext = activeDicts.firstWhere((d) => d['id'] == dictId, orElse: () => <String, dynamic>{});
      if (ext.isEmpty || ext['is_enabled'] != 1) return false;
    }
    return true;
  }
}
