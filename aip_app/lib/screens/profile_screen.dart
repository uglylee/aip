import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../screens/post_detail_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';

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

  void _showEditProfile() async {
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final bioCtrl = TextEditingController(text: user?.bio ?? '');
    String? avatarUrl = user?.avatar;
    File? avatarFile;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑资料'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512, maxHeight: 512);
                  if (picked != null) {
                    setDialogState(() => avatarFile = File(picked.path));
                  }
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue[50],
                  backgroundImage: avatarFile != null ? FileImage(avatarFile!) : null,
                  child: avatarFile == null
                      ? Text(user?.username?[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              const Text('点击更换头像', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: '用户名')),
              const SizedBox(height: 12),
              TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: '简介'), maxLines: 3),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(onPressed: () async {
              if (avatarFile != null) {
                final url = await ApiService.uploadFile(avatarFile!);
                if (url != null) avatarUrl = url;
              }
              await ApiService.updateUser(myId, username: usernameCtrl.text, bio: bioCtrl.text, avatar: avatarUrl);
              Navigator.pop(ctx);
              _load();
            }, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == null || widget.userId == myId;
    return Scaffold(
      appBar: AppBar(
        title: Text(user?.username ?? ''),
        actions: isMe ? [
          IconButton(icon: const Icon(Icons.edit), onPressed: _showEditProfile),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())).then((_) => _load())),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await ApiService.clearToken();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
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
                    Center(child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[50],
                      backgroundImage: user!.avatar.isNotEmpty ? NetworkImage('${ApiService.baseUrl}${user!.avatar}') : null,
                      child: user!.avatar.isEmpty ? Text(user!.username[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)) : null,
                    )),
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
                    if (isMe) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('退出登录'),
                                  content: const Text('确定要退出登录吗？'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ApiService.clearToken();
                                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                              }
                            },
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text('退出登录', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
    );
  }
}
