import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class AddCharacterScreen extends StatefulWidget {
  final Function(String imagePath, String roleName, String systemPrompt)
      onAddRole;
  final bool isEditing;
  final String? initialRoleName;
  final String? initialSystemPrompt;
  final String? initialImagePath;

  const AddCharacterScreen({
    super.key,
    required this.onAddRole,
    this.isEditing = false,
    this.initialRoleName,
    this.initialSystemPrompt,
    this.initialImagePath,
  });

  @override
  _AddCharacterScreenState createState() => _AddCharacterScreenState();
}

class _AddCharacterScreenState extends State<AddCharacterScreen> {
  final TextEditingController _roleNameController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _roleNameController.text = widget.initialRoleName ?? '';
      _systemPromptController.text = widget.initialSystemPrompt ?? '';
      _imagePath = widget.initialImagePath;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '修改聊天角色' : '添加聊天角色'),
      ),
      body: Column(
        children: [
          // 可滑动内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _roleNameController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: '角色名称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _systemPromptController,
                    maxLength: 1000, // 设置最大字符数
                    decoration: const InputDecoration(
                      labelText: '系统提示词',
                      // counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('选择图片'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 图片显示区域
                  Center(
                    child: _imagePath != null && _imagePath!.isNotEmpty
                        ? Container(
                            width: 300.0,
                            height: 300.0,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: kIsWeb
                                  ? Image.network(
                                      _imagePath!,
                                      fit: BoxFit.contain,
                                    )
                                  : Image.file(
                                      File(_imagePath!),
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          )
                        : Container(
                            width: 300.0,
                            height: 300.0,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.image,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8.0),
                                Text(
                                  '未选择图片',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // 固定的底部按钮区域
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_roleNameController.text.isNotEmpty &&
                        _systemPromptController.text.isNotEmpty) {
                      widget.onAddRole(
                        _imagePath ?? '',
                        _roleNameController.text,
                        _systemPromptController.text,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
