import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'friends_screen.dart';
import 'group_list_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> conversations = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.getConversations();
      if (mounted) setState(() { conversations = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      return '${date.month}/${date.day}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())).then((_) => _load()), tooltip: '好友'),
          IconButton(icon: const Icon(Icons.group_add), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupListScreen())).then((_) => _load()), tooltip: '群聊'),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.email_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无私信', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ]))
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
                  itemBuilder: (ctx, i) {
                    final conv = conversations[i];
                    final user = conv['user'];
                    final lastMsg = conv['lastMessage'];
                    final unread = conv['unread'] ?? 0;
                    return ListTile(
                      leading: CircleAvatar(child: Text((user?['username'] ?? '?')[0].toUpperCase())),
                      title: Text(user?['username'] ?? '未知', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMsg?['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_formatTime(lastMsg?['createdAt']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        if (unread > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ]),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatScreen(userId: user?['_id'] ?? '', userName: user?['username'] ?? ''),
                      )).then((_) => _load()),
                    );
                  },
                ),
    );
  }
}
