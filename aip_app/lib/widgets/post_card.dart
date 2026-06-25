import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import 'user_avatar.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onRetweet;
  final VoidCallback? onAvatarTap;
  final bool isOwner;
  const PostCard({super.key, required this.post, this.onTap, this.onDelete, this.onLike, this.onRetweet, this.onAvatarTap, this.isOwner = false});

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _formatTime(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟';
      if (diff.inDays < 1) return '${diff.inHours}小时';
      if (diff.inDays < 7) return '${diff.inDays}天';
      return '${date.month}/${date.day}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final hasMedia = post.images.isNotEmpty || post.videos.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: UserAvatar(avatarUrl: author?.avatar, username: author?.username ?? '?', radius: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(author?.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: Color(0xFF1DA1F2)),
                      const SizedBox(width: 4),
                      Text('· ${_formatTime(post.createdAt)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ]),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'delete') onDelete?.call(); },
                    itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red)))],
                  ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(post.content, style: const TextStyle(fontSize: 15)),
            ],
            if (hasMedia) ...[
              const SizedBox(height: 12),
              _buildMediaGrid(context),
            ],
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _iconBtn(Icons.chat_bubble_outline, _formatCount(post.replyCount), onTap),
              _iconBtn(Icons.repeat, _formatCount(post.retweets), onRetweet),
              _iconBtn(post.isLiked ? Icons.favorite : Icons.favorite_border, _formatCount(post.likes), onLike, color: post.isLiked ? Colors.red : Colors.grey),
              _iconBtn(Icons.bar_chart, _formatCount(post.viewCount), null),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(BuildContext context) {
    final allMedia = <_MediaItem>[
      ...post.images.map((url) => _MediaItem(url: url, isVideo: false)),
      ...post.videos.asMap().entries.map((e) => _MediaItem(url: e.value, isVideo: true, thumbnail: e.key < post.thumbnails.length ? post.thumbnails[e.key] : null)),
    ];
    if (allMedia.length == 1) {
      return _buildSingleMedia(context, allMedia[0]);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1,
      children: allMedia.take(4).map((m) => _buildGridItem(context, m)).toList(),
    );
  }

  Widget _buildSingleMedia(BuildContext context, _MediaItem item) {
    if (item.isVideo) {
      return _VideoThumbnail(url: item.url, thumbnail: item.thumbnail);
    }
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, item.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: '${ApiService.baseUrl}${item.url}',
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(height: 200, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, __, ___) => Container(height: 200, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, _MediaItem item) {
    if (item.isVideo) {
      return _VideoThumbnail(url: item.url, thumbnail: item.thumbnail);
    }
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, item.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: '${ApiService.baseUrl}${item.url}',
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: '${ApiService.baseUrl}${url}',
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback? onTap, {Color color = Colors.grey}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ]),
    );
  }
}

class _MediaItem {
  final String url;
  final bool isVideo;
  final String? thumbnail;
  const _MediaItem({required this.url, required this.isVideo, this.thumbnail});
}

class _VideoThumbnail extends StatelessWidget {
  final String url;
  final String? thumbnail;
  const _VideoThumbnail({required this.url, this.thumbnail});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoPlayerScreen(url: url))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
          height: 200,
          child: Stack(fit: StackFit.expand, children: [
            if (thumbnail != null && thumbnail!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: '${ApiService.baseUrl}$thumbnail',
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.black87),
                errorWidget: (_, __, ___) => Container(color: Colors.black87),
              )
            else
              Container(color: Colors.black87),
            Center(child: Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
            )),
          ]),
        ),
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String url;
  const _VideoPlayerScreen({required this.url});
  @override State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final videoUrl = '${ApiService.baseUrl}${widget.url}';
    print('[VideoPlayer] URL: $videoUrl');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => print('[VideoWebView] Started: $url'),
        onPageFinished: (url) { print('[VideoWebView] Finished: $url'); setState(() => _loading = false); },
        onWebResourceError: (e) => print('[VideoWebView] Error: ${e.description}'),
      ))
      ..loadRequest(Uri.parse(videoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), title: const Text('视频播放', style: TextStyle(color: Colors.white))),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
      ]),
    );
  }
}
