import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupChatScreen({super.key, required this.groupId, required this.groupName});
  @override State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  List<dynamic> messages = [];
  final msgCtrl = TextEditingController();
  String myId = '';
  List<dynamic> members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final me = await ApiService.getMe();
      myId = me?['id'] ?? '';
      final result = await ApiService.getGroupMessages(widget.groupId);
      final group = await ApiService.getGroup(widget.groupId);
      if (mounted) setState(() { messages = result; members = group?['members'] ?? []; });
    } catch (_) {}
  }

  String _getSenderName(String senderId) {
    final member = members.firstWhere((m) => (m['_id'] ?? m['id']) == senderId, orElse: () => null);
    return member?['username'] ?? '未知';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${members.length}位成员', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: messages.length,
            itemBuilder: (ctx, i) {
              final msg = messages[i];
              final isMe = msg['sender'] == myId;
              final senderName = _getSenderName(msg['sender']);
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!isMe) Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(senderName, style: const TextStyle(fontSize: 12, color: Color(0xFF1DA1F2), fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF1DA1F2) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(msg['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE1E8ED)))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: msgCtrl,
                decoration: InputDecoration(hintText: '发送群消息', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: msgCtrl.text.isEmpty ? null : () async {
                final text = msgCtrl.text;
                msgCtrl.clear();
                await ApiService.sendGroupMessage(widget.groupId, text);
                _load();
              },
              icon: const Icon(Icons.send, color: Color(0xFF1DA1F2)),
            ),
          ]),
        ),
      ]),
    );
  }
}
