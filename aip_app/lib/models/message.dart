class ChatMessage {
  final String id, sender, content, createdAt;
  ChatMessage({required this.id, required this.sender, required this.content, required this.createdAt});
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] ?? j['_id'] ?? '',
    sender: j['sender'] ?? '',
    content: j['content'] ?? '',
    createdAt: j['createdAt'] ?? '',
  );
}
