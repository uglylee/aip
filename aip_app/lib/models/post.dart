import 'user.dart';

class Post {
  final String id, content, createdAt;
  final User? author;
  final List<String> images;
  final List<String> videos;
  final List<String> thumbnails;
  final List<String> likesId;
  final int likes, retweets, viewCount, replyCount;
  bool isLiked;
  Post({required this.id, required this.content, required this.createdAt, this.author, this.images=const [], this.videos=const [], this.thumbnails=const [], this.likesId=const [], this.likes=0, this.retweets=0, this.viewCount=0, this.replyCount=0, this.isLiked=false});
  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'] ?? j['_id'] ?? '',
    content: j['content'] ?? '',
    createdAt: j['createdAt'] ?? '',
    author: j['author'] != null ? User.fromJson(j['author']) : null,
    images: (j['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
    videos: (j['videos'] as List?)?.map((e) => e.toString()).toList() ?? [],
    thumbnails: (j['thumbnails'] as List?)?.map((e) => e.toString()).toList() ?? [],
    likesId: (j['likes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    likes: (j['likes'] as List?)?.length ?? 0,
    retweets: (j['retweets'] as List?)?.length ?? 0,
    viewCount: j['viewCount'] ?? 0,
    replyCount: j['replyCount'] ?? 0,
    isLiked: false,
  );
}
