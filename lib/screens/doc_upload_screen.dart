import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../database/file_database_helper.dart'; // 导入 FileDatabaseHelper

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  _DocumentUploadScreenState createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  String _statusMessage = '';
  final FileDatabaseHelper _fileDbHelper = FileDatabaseHelper.instance;
  List<Map<String, dynamic>> _uploadedFiles = []; // 存储上传的文件信息

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await _fileDbHelper.getAllFiles();
    setState(() {
      _uploadedFiles = files;
    });
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        final file = result.files.single;

        if (kIsWeb) {
          // Web 平台：使用字节数据
          if (file.bytes != null) {
            final Uint8List fileBytes = file.bytes!;
            final fileName = file.name;

            // 存储文件到 SQLite
            await _fileDbHelper.insertFile(
              DateTime.now().millisecondsSinceEpoch.toString(),
              fileName,
              fileBytes,
            );

            setState(() {
              _statusMessage = '文件上传成功！字节大小：${fileBytes.length}';
            });
          } else {
            setState(() {
              _statusMessage = '文件不可用。';
            });
          }
        } else {
          // 非 Web 平台：使用文件路径
          if (file.path != null) {
            final filePath = file.path!;
            final fileName = file.name;
            final fileBytes = await File(filePath).readAsBytes();

            // 存储文件到 SQLite
            await _fileDbHelper.insertFile(
              DateTime.now().millisecondsSinceEpoch.toString(),
              fileName,
              fileBytes,
            );

            setState(() {
              _statusMessage = '文件上传成功！路径：$filePath';
            });
          } else {
            setState(() {
              _statusMessage = '文件不可用。';
            });
          }
        }

        // 重新加载文件列表
        await _loadFiles();
      } else {
        setState(() {
          _statusMessage = '未选择文件。';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '文件上传失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('上传文档'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _uploadFile,
            child: const Text('选择文件并上传'),
          ),
          const SizedBox(height: 20),
          Text(_statusMessage),
          Expanded(
            child: _buildFileGrid(), // 展示上传的文件
          ),
        ],
      ),
    );
  }

  Widget _buildFileGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 双列布局
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8, // 调整宽高比
      ),
      itemCount: _uploadedFiles.length,
      itemBuilder: (context, index) {
        final file = _uploadedFiles[index];
        return GestureDetector(
          onTap: () {
            // 点击查看文件内容
            _showFileContent(file);
          },
          child: Card(
            child: Column(
              children: [
                Expanded(
                  child: file['bytes'] != null
                      ? Image.memory(
                          file['bytes'],
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.insert_drive_file, size: 50),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    file['name'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  '上传时间：${file['upload_time']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFileContent(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(file['name']),
          content: file['bytes'] != null
              ? Image.memory(file['bytes'])
              : const Text('无法预览文件内容。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
