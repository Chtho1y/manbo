import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'add_character_screen.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<String> _saveImageToLocalDirectory(String imagePath) async {
    try {
      final directory = await getExternalStorageDirectory();
      final imageName = imagePath.split('/').last;
      final newImagePath = '${directory?.path}/$imageName';
      final sourceFile = File(imagePath);
      if (await sourceFile.exists()) {
        final newImageFile = await sourceFile.copy(newImagePath);
        return newImageFile.path;
      } else {
        return '';
      }
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return '';
    }
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

  void _upsertChatRole({
    int? index,
    required String imagePath,
    required String roleName,
    required String systemPrompt,
  }) async {
    final newPath = await _saveImageToLocalDirectory(imagePath);
    if (index != null) {
      final oldImagePath = chatRoles[index]['imagePath'];
      if (oldImagePath != null && oldImagePath != newPath) {
        final oldImageFile = File(oldImagePath);
        if (await oldImageFile.exists()) {
          try {
            await oldImageFile.delete();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除旧图片文件时出错: $e')),
            );
          }
        }
      }
    }
    setState(() {
      final chatRole = {
        'imagePath': newPath,
        'roleName': roleName,
        'systemPrompt': systemPrompt,
        'isApplied': false,
      };
      if (index != null) {
        chatRoles[index] = chatRole;
      } else {
        chatRoles.add(chatRole);
      }
    });

    _saveChatRoles();
  }

  void _deleteChatRole(int index) {
    final imagePath = chatRoles[index]['imagePath'];
    if (imagePath != null && File(imagePath).existsSync()) {
      File(imagePath).deleteSync();
    }
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
        title: const Text('角色广场'),
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
                      _upsertChatRole(
                        imagePath: imagePath,
                        roleName: roleName,
                        systemPrompt: systemPrompt,
                      );
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
                  SnackBar(content: Text('角色“$roleName”已应用，快去发起对话吧~')),
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
                        _upsertChatRole(
                          index: index,
                          imagePath: imagePath,
                          roleName: roleName,
                          systemPrompt: systemPrompt,
                        );
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
