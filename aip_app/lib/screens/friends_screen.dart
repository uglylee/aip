import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<dynamic> friends = [];
  List<dynamic> pendingRequests = [];
  bool loading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final f = await ApiService.getFriends();
      final p = await ApiService.getPendingRequests();
      if (mounted) setState(() { friends = f; pendingRequests = p; loading = false; });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(children: [
            Expanded(child: _tabBtn('好友', 0)),
            Expanded(child: _tabBtn('请求${pendingRequests.isNotEmpty ? " (${pendingRequests.length})" : ""}', 1)),
          ]),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _currentTab == 0 ? _buildFriendsList() : _buildRequestsList(),
    );
  }

  Widget _tabBtn(String label, int index) {
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? const Color(0xFF1DA1F2) : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFF1DA1F2) : Colors.grey, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (friends.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('暂无好友', style: TextStyle(color: Colors.grey, fontSize: 16)),
      ]));
    }
    return ListView.separated(
      itemCount: friends.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
      itemBuilder: (ctx, i) {
        final u = friends[i];
        return ListTile(
          leading: CircleAvatar(child: Text((u['username'] ?? '?')[0].toUpperCase())),
          title: Text(u['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('@${u['handle'] ?? ''}'),
          trailing: IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1DA1F2)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(userId: u['_id'] ?? u['id'] ?? '', userName: u['username'] ?? ''))),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: u['_id'] ?? u['id']))),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    if (pendingRequests.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person_add_disabled, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('暂无好友请求', style: TextStyle(color: Colors.grey, fontSize: 16)),
      ]));
    }
    return ListView.separated(
      itemCount: pendingRequests.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE1E8ED)),
      itemBuilder: (ctx, i) {
        final r = pendingRequests[i];
        final from = r['from'];
        return ListTile(
          leading: CircleAvatar(child: Text((from?['username'] ?? '?')[0].toUpperCase())),
          title: Text(from?['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('@${from?['handle'] ?? ''}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () async {
                await ApiService.acceptFriendRequest(r['_id'] ?? r['id']);
                _load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () async {
                await ApiService.declineFriendRequest(r['_id'] ?? r['id']);
                _load();
              },
            ),
          ]),
        );
      },
    );
  }
}
