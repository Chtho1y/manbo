/// 对话数据结构
class Chat {
  String id;
  String name;
  List<Message> messages;

  Chat({required this.id, required this.name, required this.messages});
}

/// 对话消息数据结构
class Message {
  String id;
  String role;
  String content;

  Message({required this.id, required this.role, required this.content});
}
