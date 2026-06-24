import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'group_chat_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});
  @override State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  List<dynamic> groups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.getGroups();
      if (mounted) setState(() { groups = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _createGroup() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建群聊'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: '群名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text), child: const Text('创建')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ApiService.createGroup(result, []);
      _load();
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
      appBar: AppBar(title: const Text('群聊', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1DA1F2),
        onPressed: _createGroup,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.group_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无群聊', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('点击右下角创建', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]))
              : ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
                  itemBuilder: (ctx, i) {
                    final g = groups[i];
                    final group = g['group'];
                    final lastMsg = g['lastMessage'];
                    final memberCount = (group['members'] as List?)?.length ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1DA1F2).withOpacity(0.1),
                        child: const Icon(Icons.group, color: Color(0xFF1DA1F2)),
                      ),
                      title: Text(group['name'] ?? '未命名群聊', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        lastMsg != null ? '${lastMsg['content'] ?? ''} · $memberCount人' : '$memberCount位成员',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      trailing: lastMsg != null ? Text(_formatTime(lastMsg['createdAt']), style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GroupChatScreen(groupId: group['_id'] ?? group['id'], groupName: group['name'] ?? '群聊'),
                      )).then((_) => _load()),
                    );
                  },
                ),
    );
  }
}
