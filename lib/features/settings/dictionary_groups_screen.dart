import 'package:flutter/material.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:hdict/core/manager/dictionary_group_manager.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';

class DictionaryGroupsScreen extends StatefulWidget {
  const DictionaryGroupsScreen({super.key});

  @override
  State<DictionaryGroupsScreen> createState() => _DictionaryGroupsScreenState();
}

class _DictionaryGroupsScreenState extends State<DictionaryGroupsScreen> {
  List<DictionaryGroup> _groups = [];
  List<Map<String, dynamic>> _allDictionaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final dicts = await DictionaryManager.instance.getDictionaries();
    final groups = await DictionaryGroupManager.getGroups();
    
    setState(() {
      _allDictionaries = dicts;
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _createCustomGroup() async {
    final TextEditingController nameController = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Custom Group'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Group Name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = nameController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await DictionaryGroupManager.createCustomGroup(result);
      await _loadData();
    }
  }

  Future<void> _manageGroupDictionaries(DictionaryGroup group) async {
    final List<int> originalDictIds = List.from(group.dictIds);
    final List<int> selectedDictIds = List.from(group.dictIds);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage "${group.name}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allDictionaries.length,
                  itemBuilder: (context, index) {
                    final dict = _allDictionaries[index];
                    final dictId = dict['id'] as int;
                    final isSelected = selectedDictIds.contains(dictId);
                    
                    return CheckboxListTile(
                      title: Text(dict['name']),
                      subtitle: Text('${dict['word_count']} headwords'),
                      value: isSelected,
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selectedDictIds.add(dictId);
                          } else {
                            selectedDictIds.remove(dictId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((saved) async {
      if (saved == true) {
         // Apply removals and additions
         for (int id in originalDictIds) {
            if (!selectedDictIds.contains(id)) {
               await DictionaryGroupManager.removeDictionaryFromGroup(group.id, id);
            }
         }
         for (int id in selectedDictIds) {
            if (!originalDictIds.contains(id)) {
               await DictionaryGroupManager.addDictionaryToGroup(group.name, id);
            }
         }
         await _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary Groups'),
        actions: [
           IconButton(
             icon: const Icon(Icons.add),
             onPressed: _createCustomGroup,
             tooltip: 'Create Custom Group',
           )
        ],
      ),
      drawer: const AppDrawer(),
      body: _groups.isEmpty
          ? const Center(child: Text('No dictionary groups available.'))
          : ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return FutureBuilder<bool>(
                  future: DictionaryGroupManager.isGroupActive(group.id),
                  builder: (context, snapshot) {
                    final isActive = snapshot.data ?? false;
                    
                    return ListTile(
                      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${group.dictIds.length} dictionaries'),
                      trailing: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                            Switch(
                              value: isActive,
                              onChanged: group.dictIds.isEmpty ? null : (bool value) async {
                                 await DictionaryGroupManager.toggleGroup(group.id, value);
                                 setState(() {}); // refresh the whole list to show updated active states
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) async {
                                 if (val == 'edit') {
                                    await _manageGroupDictionaries(group);
                                 } else if (val == 'delete') {
                                    await DictionaryGroupManager.deleteGroup(group.id);
                                    await _loadData();
                                 }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Manage Dictionaries')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete Group', style: TextStyle(color: Colors.red))),
                              ]
                            )
                         ],
                      ),
                      onTap: () => _manageGroupDictionaries(group),
                    );
                  },
                );
              },
            ),
    );
  }
}
