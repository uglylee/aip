import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool loading = true;
  StreamSubscription? _notifSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _notifSub = SocketService.on('notification').listen((_) {
      if (mounted) _load();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await ApiService.getNotifications();
      if (mounted) setState(() { notifications = result; loading = false; });
      await ApiService.markAllRead();
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatTime(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${date.month}/${date.day}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知', style: TextStyle(fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无通知', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
                    itemBuilder: (ctx, i) {
                      final n = notifications[i];
                      final fromUser = n['fromUser'];
                      String text;
                      IconData icon;
                      Color iconColor;
                      switch (n['type']) {
                        case 'like': text = '赞了你的帖子'; icon = Icons.favorite; iconColor = Colors.red; break;
                        case 'retweet': text = '转发了你的帖子'; icon = Icons.repeat; iconColor = Colors.green; break;
                        case 'follow': text = '关注了你'; icon = Icons.person_add; iconColor = const Color(0xFF1DA1F2); break;
                        case 'reply': text = '回复了你的帖子'; icon = Icons.chat_bubble; iconColor = Colors.purple; break;
                        case 'friend_request': text = '发送了好友请求'; icon = Icons.person_add; iconColor = Colors.orange; break;
                        default: text = '与你互动'; icon = Icons.notifications; iconColor = Colors.grey;
                      }
                      final hasPost = n['postId'] != null && n['type'] != 'follow' && n['type'] != 'friend_request';
                      return ListTile(
                        leading: GestureDetector(
                          onTap: () {
                            final userId = fromUser?['id'] ?? fromUser?['_id'];
                            if (userId != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
                          },
                          child: CircleAvatar(
                            backgroundColor: iconColor.withValues(alpha: 0.1),
                            child: Icon(icon, color: iconColor, size: 20),
                          ),
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black, fontSize: 14),
                            children: [
                              TextSpan(text: fromUser?['username'] ?? '未知', style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: ' $text'),
                            ],
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatTime(n['createdAt'] ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (hasPost && n['post']?['content'] != null)
                              Text(n['post']['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        trailing: n['read'] == true ? null : Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1DA1F2), shape: BoxShape.circle)),
                        onTap: hasPost ? () {
                          final postId = n['postId'];
                          if (postId != null) Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)));
                        } : null,
                      );
                    },
                  ),
                ),
    );
  }
}
