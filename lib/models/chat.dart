class Chat {
  String id;
  String name;
  List<Message> messages;

  Chat({required this.id, required this.name, required this.messages});
}

class Message {
  String id;
  String role; // 'user' 或 'assistant'
  String content;

  Message({required this.id, required this.role, required this.content});
}
