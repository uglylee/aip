class User {
  final String id, username, handle, avatar, bio;
  final int followers, following;
  final bool isFollowing;
  User({required this.id, required this.username, required this.handle, this.avatar='', this.bio='', this.followers=0, this.following=0, this.isFollowing=false});
  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] ?? j['_id'] ?? '',
    username: j['username'] ?? '',
    handle: j['handle'] ?? '',
    avatar: j['avatar'] ?? '',
    bio: j['bio'] ?? '',
    followers: j['followers'] is int ? j['followers'] : (j['followers'] as List?)?.length ?? 0,
    following: j['following'] is int ? j['following'] : (j['following'] as List?)?.length ?? 0,
    isFollowing: j['isFollowing'] ?? false,
  );
}
