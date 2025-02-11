import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'add_character_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
    String newPath;
    double aspectRatio = 1.0; // 默认宽高比

    try {
      final decodedImage =
          await decodeImageFromList(File(imagePath).readAsBytesSync());
      aspectRatio = decodedImage.width / decodedImage.height;
    } catch (e) {
      debugPrint('获取图片宽高比失败: $e');
    }

    if (index != null) {
      final oldImagePath = chatRoles[index]['imagePath'];
      if (oldImagePath != null && oldImagePath == imagePath) {
        newPath = oldImagePath;
      } else {
        newPath = await _saveImageToLocalDirectory(imagePath);
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
    } else {
      newPath = await _saveImageToLocalDirectory(imagePath);
    }

    setState(() {
      final chatRole = {
        'imagePath': newPath,
        'roleName': roleName,
        'systemPrompt': systemPrompt,
        'isApplied': false,
        'aspectRatio': aspectRatio,
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

  Future<void> _showBottomSheet(int index) async {
    final role = chatRoles[index];
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
  }

  Widget _buildImageWidget(String imagePath, double aspectRatio) {
    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image,
          size: 50,
          color: Colors.grey,
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image,
          size: 50,
          color: Colors.grey,
        ),
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
            icon: const Icon(FeatherIcons.plus),
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: chatRoles.isEmpty
            ? const Center(
                child: Text('暂无角色，点击右上角加号添加角色',
                    style: const TextStyle(
                      fontSize: 18.0,
                    )),
              )
            : MasonryGridView.builder(
                gridDelegate:
                    const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 设置为两列
                ),
                mainAxisSpacing: 12.0,
                crossAxisSpacing: 12.0,
                itemCount: chatRoles.length,
                itemBuilder: (context, index) {
                  final role = chatRoles[index];
                  final aspectRatio = role['aspectRatio'] ?? 1.0; // 默认宽高比
                  final roleName = role['roleName'] ?? '角色名';
                  final imagePath = role['imagePath'] ?? '';

                  return GestureDetector(
                    onTap: () async {
                      final systemPrompt = role['systemPrompt'];
                      final appliedRoleName = roleName;
                      if (systemPrompt != null && systemPrompt.isNotEmpty) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('systemPrompt', systemPrompt);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('角色“$appliedRoleName”已应用，快去发起对话吧~'),
                          ),
                        );
                      }
                    },
                    onLongPress: () => _showBottomSheet(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6.0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 使用 LayoutBuilder 计算图片高度
                                LayoutBuilder(
                                  builder: (BuildContext context,
                                      BoxConstraints constraints) {
                                    final cardWidth =
                                        (constraints.maxWidth - 0) /
                                            1; // 1因为crossAxisCount=2
                                    final imageHeight = cardWidth / aspectRatio;

                                    return SizedBox(
                                      width: double.infinity,
                                      height: imageHeight,
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12.0),
                                          topRight: Radius.circular(12.0),
                                        ),
                                        child: imagePath.isNotEmpty
                                            ? _buildImageWidget(
                                                imagePath, aspectRatio)
                                            : const Icon(
                                                Icons.image,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                      ),
                                    );
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    roleName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // 这里可以添加覆盖层，例如加载中或错误状态等
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
