import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchCtrl = TextEditingController();
  List<Post> posts = [];
  List<User> users = [];
  bool searched = false;
  bool loading = false;

  void doSearch() async {
    if (searchCtrl.text.trim().isEmpty) return;
    setState(() { loading = true; searched = true; });
    try {
      final result = await ApiService.search(searchCtrl.text);
      if (result != null && mounted) {
        setState(() {
          posts = (result['posts'] as List? ?? []).map((e) => Post.fromJson(e)).toList();
          users = (result['users'] as List? ?? []).map((e) => User.fromJson(e)).toList();
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
      appBar: AppBar(
        title: TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(hintText: '搜索用户、帖子', border: InputBorder.none),
          onSubmitted: (_) => doSearch(),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: doSearch)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !searched
              ? const Center(child: Text('输入关键词搜索', style: TextStyle(color: Colors.grey)))
              : ListView(
                  children: [
                    if (users.isNotEmpty) ...[
                      const Padding(padding: EdgeInsets.all(16), child: Text('用户', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      ...users.map((u) => ListTile(
                        leading: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: u.id))),
                          child: UserAvatar(avatarUrl: u.avatar, username: u.username),
                        ),
                        title: Text(u.username),
                        subtitle: Text('@${u.handle}'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: u.id))),
                      )).toList(),
                    ],
                    if (posts.isNotEmpty) ...[
                      const Padding(padding: EdgeInsets.all(16), child: Text('帖子', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      ...posts.map((p) => PostCard(post: p, onTap: () {})).toList(),
                    ],
                    if (users.isEmpty && posts.isEmpty)
                      const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('没有找到结果', style: TextStyle(color: Colors.grey)))),
                  ],
                ),
    );
  }
}
