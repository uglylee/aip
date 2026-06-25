import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/post_card.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Post> posts = [];
  bool loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _currentTab = 0;
  User? currentUser;
  int _unreadCount = 0;
  int _unreadMsgCount = 0;
  StreamSubscription? _notificationSub;
  StreamSubscription? _messageSub;
  Timer? _unreadPollTimer;
  AppLifecycleState? _lastLifecycleState;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadData();
    _initSocket();
    _listenNotifications();
    _listenMessages();
    _unreadPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadUnreadCount();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  int _lastUnreadMsgCount = 0;
  int _lastUnreadNotifCount = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBackground = _lastLifecycleState != null && _lastLifecycleState != AppLifecycleState.resumed;
    _lastLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      SocketService.connect();
      if (wasBackground) _checkMissedMessages();
      _loadUnreadCount();
    }
  }

  void _checkMissedMessages() async {
    try {
      final results = await Future.wait([
        ApiService.getUnreadMessageCount(),
        ApiService.getUnreadCount(),
      ]);
      final newMsgCount = results[0] as int;
      final newNotifCount = results[1] as int;

      if (newMsgCount > _lastUnreadMsgCount) {
        final diff = newMsgCount - _lastUnreadMsgCount;
        NotificationService.showMessageNotification(
          title: '新私信',
          body: '你有 $diff 条未读消息',
        );
      }
      if (newNotifCount > _lastUnreadNotifCount) {
        final diff = newNotifCount - _lastUnreadNotifCount;
        NotificationService.showGenericNotification(
          title: '新通知',
          body: '你有 $diff 条新通知',
        );
      }

      _lastUnreadMsgCount = newMsgCount;
      _lastUnreadNotifCount = newNotifCount;
    } catch (_) {}
  }

  bool get _isInBackground => _lastLifecycleState != null && _lastLifecycleState != AppLifecycleState.resumed;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _notificationSub?.cancel();
    _messageSub?.cancel();
    _unreadPollTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final feed = await ApiService.getFeed(page: _page + 1);
      if (feed.isEmpty) {
        _hasMore = false;
      } else {
        _page++;
        final newPosts = feed.map((e) => Post.fromJson(e)).toList();
        if (currentUser != null) {
          for (var p in newPosts) {
            p.isLiked = p.likesId.contains(currentUser!.id);
          }
        }
        setState(() => posts.addAll(newPosts));
      }
    } catch (_) {}
    setState(() => _loadingMore = false);
  }

  void _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ws_debug', 'initState called, token=${ApiService.token != null}');
    SocketService.connect();
    await Future.delayed(const Duration(seconds: 3));
    await prefs.setString('ws_debug2', 'connected=${SocketService.isConnected}');
  }

  void _listenMessages() {
    _messageSub = SocketService.on('message').listen((data) {
      if (mounted) _loadUnreadCount();
      if (_isInBackground) {
        final sender = data['senderName'] ?? '新消息';
        final content = data['content'] ?? '';
        NotificationService.showMessageNotification(title: sender, body: content);
      }
    });
  }

  void _listenNotifications() {
    _notificationSub = SocketService.on('notification').listen((data) {
      if (mounted) _loadUnreadCount();
      if (_isInBackground) {
        final type = data['type'] ?? '';
        String text;
        switch (type) {
          case 'like': text = '赞了你的帖子'; break;
          case 'retweet': text = '转发了你的帖子'; break;
          case 'follow': text = '关注了你'; break;
          case 'reply': text = '回复了你的帖子'; break;
          case 'friend_request': text = '发送了好友请求'; break;
          default: text = '与你互动';
        }
        NotificationService.showGenericNotification(title: '新通知', body: text);
      }
    });
  }

  Future<void> _loadData() async {
    try {
      _page = 1;
      _hasMore = true;
      final meFuture = ApiService.getMe();
      final feedFuture = ApiService.getFeed(page: 1);
      final results = await Future.wait([meFuture, feedFuture]);
      final meResult = results[0] as Map<String, dynamic>?;
      currentUser = meResult != null ? User.fromJson(meResult) : null;
      var feed = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
      _loadUnreadCount();
    } catch (e) {
      if (mounted) setState(() { loading = false; });
    }
  }

  void _loadUnreadCount() async {
    try {
      final results = await Future.wait([
        ApiService.getUnreadCount(),
        ApiService.getUnreadMessageCount(),
      ]);
      if (mounted) setState(() {
        _unreadCount = results[0] as int;
        _unreadMsgCount = results[1] as int;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHomeTab(),
          const AiChatScreen(),
          const NotificationsScreen(),
          const MessagesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) {
          setState(() => _currentTab = i);
          if (i == 2 || i == 3) _loadUnreadCount();
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          const NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'AI'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: '通知',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadMsgCount > 0,
              label: Text('$_unreadMsgCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
              child: const Icon(Icons.email_outlined),
            ),
            label: '消息',
          ),
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
                  onRefresh: _loadData,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: posts.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
                    itemBuilder: (ctx, i) {
                      if (i == posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
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
