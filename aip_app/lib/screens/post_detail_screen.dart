import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});
  @override State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? post;
  List<Post> replies = [];
  bool loading = true;
  final replyCtrl = TextEditingController();
  String myId = '';
  bool _replyChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
    replyCtrl.addListener(() {
      final hasText = replyCtrl.text.isNotEmpty;
      if (hasText != _replyChanged) setState(() => _replyChanged = hasText);
    });
  }

  @override
  void dispose() {
    replyCtrl.dispose();
    super.dispose();
  }

  void _load() async {
    try {
      final me = await ApiService.getMe();
      myId = me?['id'] ?? '';
      final result = await ApiService.getPost(widget.postId);
      if (result != null && mounted) {
        final p = Post.fromJson(result['post']);
        p.isLiked = p.likesId.contains(myId);
        final rpl = (result['replies'] as List? ?? []).map((e) => Post.fromJson(e)).toList();
        for (var r in rpl) {
          r.isLiked = r.likesId.contains(myId);
        }
        setState(() {
          post = p;
          replies = rpl;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帖子')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : post == null
              ? const Center(child: Text('帖子不存在'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          PostCard(
                            post: post!,
                            isOwner: myId == post!.author?.id,
                            onTap: () {},
                            onLike: () async {
                              if (post!.isLiked) await ApiService.unlikePost(post!.id);
                              else await ApiService.likePost(post!.id);
                              _load();
                            },
                            onAvatarTap: () {
                              if (post!.author != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: post!.author!.id)));
                            },
                          ),
                          const Divider(thickness: 0.5, color: Color(0xFFE1E8ED)),
                          if (replies.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text('回复 (${replies.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ...replies.map((r) => PostCard(
                            post: r,
                            onTap: () {},
                            onLike: () async {
                              if (r.isLiked) await ApiService.unlikePost(r.id);
                              else await ApiService.likePost(r.id);
                              _load();
                            },
                            onAvatarTap: () {
                              if (r.author != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: r.author!.id)));
                            },
                          )),
                        ],
                      ),
                    ),
                    const Divider(thickness: 0.5, color: Color(0xFFE1E8ED)),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyCtrl,
                              decoration: InputDecoration(
                                hintText: '发布你的回复',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _replyChanged ? () async {
                              final text = replyCtrl.text;
                              replyCtrl.clear();
                              await ApiService.createReply(widget.postId, text);
                              _load();
                            } : null,
                            icon: const Icon(Icons.send, color: Color(0xFF1DA1F2)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
