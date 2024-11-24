import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'add_character_screen.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  _CharacterScreenState createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  List<Map<String, dynamic>> chatRoles = [];

  @override
  void initState() {
    super.initState();
    _loadChatRoles();
  }

  Future<void> _loadChatRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rolesJson = prefs.getString('chatRoles');
    if (rolesJson != null) {
      setState(() {
        chatRoles = List<Map<String, dynamic>>.from(json.decode(rolesJson));
      });
    }
  }

  Future<void> _saveChatRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final String rolesJson = json.encode(chatRoles);
    await prefs.setString('chatRoles', rolesJson);
  }

  void _addChatRole(String imagePath, String roleName, String systemPrompt) {
    setState(() {
      chatRoles.add({
        'imagePath': imagePath,
        'roleName': roleName,
        'systemPrompt': systemPrompt,
        'isApplied': false,
      });
    });
    _saveChatRoles();
  }

  void _updateChatRole(
      int index, String imagePath, String roleName, String systemPrompt) {
    setState(() {
      chatRoles[index] = {
        'imagePath': imagePath,
        'roleName': roleName,
        'systemPrompt': systemPrompt,
        'isApplied': false,
      };
    });
    _saveChatRoles();
  }

  void _deleteChatRole(int index) {
    setState(() {
      chatRoles.removeAt(index);
    });
    _saveChatRoles();
  }

  Widget _buildImageWidget(String imagePath) {
    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏制作'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddCharacterScreen(
                    onAddRole: (imagePath, roleName, systemPrompt) {
                      _addChatRole(imagePath, roleName, systemPrompt);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: chatRoles.length,
        itemBuilder: (context, index) {
          final role = chatRoles[index];
          return GestureDetector(
            onTap: () async {
              final systemPrompt = role['systemPrompt'];
              final roleName = role['roleName'];
              if (systemPrompt != null && systemPrompt.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('systemPrompt', systemPrompt);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('角色 $roleName 系统提示词已应用')),
                );
              }
            },
            onLongPress: () async {
              final action = await showModalBottomSheet<String>(
                context: context,
                builder: (context) {
                  return Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('修改'),
                        onTap: () {
                          Navigator.pop(context, 'edit');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('删除'),
                        onTap: () {
                          Navigator.pop(context, 'delete');
                        },
                      ),
                    ],
                  );
                },
              );

              if (action == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddCharacterScreen(
                      onAddRole: (imagePath, roleName, systemPrompt) {
                        _updateChatRole(
                            index, imagePath, roleName, systemPrompt);
                      },
                      isEditing: true,
                      initialRoleName: role['roleName'],
                      initialSystemPrompt: role['systemPrompt'],
                      initialImagePath: role['imagePath'],
                    ),
                  ),
                );
              } else if (action == 'delete') {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除角色'),
                    content: const Text('确定要删除这个角色吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );

                if (shouldDelete == true) {
                  _deleteChatRole(index);
                }
              }
            },
            child: Card(
              elevation: 4.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: role['imagePath'] != null &&
                            role['imagePath'].isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: _buildImageWidget(role['imagePath']),
                            ),
                          )
                        : const Icon(
                            Icons.image,
                            size: 100,
                            color: Colors.grey,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      role['roleName'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
