import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../screens/post_detail_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  List<Post> posts = [];
  bool loading = true;
  String myId = '';
  String _friendStatus = 'none';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final me = await ApiService.getMe();
      myId = me?['id'] ?? '';
      final targetId = widget.userId ?? myId;
      final userData = await ApiService.getUser(targetId);
      user = userData != null ? User.fromJson(userData) : null;
      final postData = await ApiService.getUserPosts(targetId);
      posts = postData.map((e) => Post.fromJson(e)).toList();
      for (var p in posts) {
        p.isLiked = p.likesId.contains(myId);
      }
      if (targetId != myId) {
        final friendResult = await ApiService.getFriendStatus(targetId);
        _friendStatus = friendResult?['status'] ?? 'none';
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == null || widget.userId == myId;
    return Scaffold(
      appBar: AppBar(
        title: Text(user?.username ?? ''),
        actions: isMe ? [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())).then((_) => _load())),
        ] : [
          IconButton(icon: const Icon(Icons.email), onPressed: () {
            if (user != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(userId: user!.id, userName: user!.username)));
          }),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('用户不存在'))
              : ListView(
                  children: [
                    const SizedBox(height: 16),
                    Center(child: CircleAvatar(radius: 40, backgroundColor: Colors.blue[50], child: Text(user!.username[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 8),
                    Center(child: Text(user!.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                    Center(child: Text('@${user!.handle}', style: const TextStyle(color: Colors.grey))),
                    if (user!.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Center(child: Text(user!.bio)),
                    ],
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${user!.following} 正在关注', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Text('${user!.followers} 关注者', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    if (!isMe) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                if (user!.isFollowing) await ApiService.unfollowUser(user!.id);
                                else await ApiService.followUser(user!.id);
                                _load();
                              },
                              child: Text(user!.isFollowing ? '已关注' : '关注'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                if (_friendStatus == 'none') {
                                  await ApiService.sendFriendRequest(user!.id);
                                  _load();
                                }
                              },
                              child: Text(
                                _friendStatus == 'accepted' ? '已添加好友'
                                : _friendStatus == 'pending' ? '已发送请求'
                                : _friendStatus == 'received' ? '接受请求'
                                : '添加好友',
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ],
                    const Divider(),
                    ...posts.map((p) => PostCard(
                      post: p,
                      isOwner: myId == p.author?.id,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))).then((_) => _load()),
                      onDelete: () async { await ApiService.deletePost(p.id); _load(); },
                      onLike: () async {
                        if (p.isLiked) await ApiService.unlikePost(p.id);
                        else await ApiService.likePost(p.id);
                        _load();
                      },
                      onAvatarTap: () {
                        if (p.author != null && p.author!.id != myId) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: p.author!.id))).then((_) => _load());
                        }
                      },
                    )),
                  ],
                ),
    );
  }
}
