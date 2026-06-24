import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/post_card.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'ai_chat_screen.dart';
import 'create_post_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> posts = [];
  bool loading = true;
  int _currentTab = 0;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final me = await ApiService.getMe();
      currentUser = me != null ? User.fromJson(me) : null;
      var feed = await ApiService.getFeed();
      if (feed.isEmpty) feed = await ApiService.getExplore();
      if (mounted) {
        setState(() {
          posts = feed.map((e) => Post.fromJson(e)).toList();
          if (currentUser != null) {
            for (var p in posts) {
              p.isLiked = p.likesId.contains(currentUser!.id);
            }
          }
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeTab(),
      const AiChatScreen(),
      const NotificationsScreen(),
      const MessagesScreen(),
    ];
    return Scaffold(
      body: screens[_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: '通知'),
          NavigationDestination(icon: Icon(Icons.email_outlined), label: '消息'),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1DA1F2),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                _loadData();
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadData()),
        ),
        title: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text('搜索', style: TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text('暂无内容，关注一些用户吧', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: () async { _loadData(); },
                  child: ListView.separated(
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
                    itemBuilder: (ctx, i) {
                      final post = posts[i];
                      return PostCard(
                        post: post,
                        isOwner: currentUser?.id == post.author?.id,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id))).then((_) => _loadData()),
                        onDelete: () async {
                          await ApiService.deletePost(post.id);
                          _loadData();
                        },
                        onLike: () async {
                          if (post.isLiked) {
                            await ApiService.unlikePost(post.id);
                          } else {
                            await ApiService.likePost(post.id);
                          }
                          _loadData();
                        },
                        onAvatarTap: () {
                          if (post.author != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: post.author!.id)));
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
