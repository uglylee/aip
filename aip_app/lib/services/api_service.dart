import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = 'http://192.168.0.108:8005';
  static String? _token;

  static void setToken(String? t) => _token = t;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> saveToken(String t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', t);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('api_base_url');
    if (saved != null && saved.isNotEmpty) baseUrl = saved;
  }

  static Future<void> saveBaseUrl(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
  }

  static Future<JSONObject?> _get(String path) async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      final body = jsonDecode(resp.body);
      return {'error': body['error'] ?? '请求失败'};
    } catch (_) { return {'error': '网络错误'}; }
  }

  static Future<JSONObject?> _post(String path, Map<String, dynamic> data) async {
    try {
      final resp = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(data));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      final body = jsonDecode(resp.body);
      return {'error': body['error'] ?? '请求失败'};
    } catch (_) { return {'error': '网络错误'}; }
  }

  static Future<JSONObject?> _delete(String path) async {
    try {
      final resp = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      final body = jsonDecode(resp.body);
      return {'error': body['error'] ?? '请求失败'};
    } catch (_) { return {'error': '网络错误'}; }
  }

  static Future<JSONObject?> _put(String path, Map<String, dynamic> data) async {
    try {
      final resp = await http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(data));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      final body = jsonDecode(resp.body);
      return {'error': body['error'] ?? '请求失败'};
    } catch (_) { return {'error': '网络错误'}; }
  }

  // Auth
  static Future<JSONObject?> login(String email, String password) => _post('/api/auth/login', {'email': email, 'password': password});
  static Future<JSONObject?> register(String username, String handle, String email, String password) => _post('/api/auth/register', {'username': username, 'handle': handle, 'email': email, 'password': password});
  static Future<JSONObject?> getMe() => _get('/api/auth/me');

  // Posts
  static Future<List<JSONObject>> getFeed({int page = 1}) async {
    final r = await _get('/api/posts/feed?page=$page');
    return (r?['posts'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<List<JSONObject>> getExplore() async {
    final r = await _get('/api/posts/explore');
    return (r?['posts'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<JSONObject?> createPost(String content, {List<String> images = const [], List<String> videos = const [], List<String> thumbnails = const []}) => _post('/api/posts', {'content': content, 'images': images, 'videos': videos, 'thumbnails': thumbnails});
  static Future<JSONObject?> createReply(String postId, String content) => _post('/api/posts', {'content': content, 'replyTo': postId});
  static Future<JSONObject?> getPost(String postId) => _get('/api/posts/$postId');
  static Future<JSONObject?> likePost(String postId) => _post('/api/posts/$postId/like', {});
  static Future<JSONObject?> unlikePost(String postId) => _delete('/api/posts/$postId/like');
  static Future<JSONObject?> retweetPost(String postId) => _post('/api/posts/$postId/retweet', {});
  static Future<JSONObject?> undoRetweet(String postId) => _delete('/api/posts/$postId/retweet');
  static Future<JSONObject?> deletePost(String postId) => _delete('/api/posts/$postId');

  // Users
  static Future<JSONObject?> getUser(String userId) => _get('/api/users/$userId');
  static Future<JSONObject?> updateUser(String userId, {String? username, String? bio, String? avatar}) {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (bio != null) data['bio'] = bio;
    if (avatar != null) data['avatar'] = avatar;
    return _put('/api/users/$userId', data);
  }
  static Future<JSONObject?> followUser(String userId) => _post('/api/users/$userId/follow', {});
  static Future<JSONObject?> unfollowUser(String userId) => _delete('/api/users/$userId/follow');
  static Future<List<JSONObject>> getUserPosts(String userId) async {
    final r = await _get('/api/posts/user/$userId');
    return (r?['posts'] as List?)?.cast<JSONObject>() ?? [];
  }

  // Messages
  static Future<List<JSONObject>> getConversations() async {
    final r = await _get('/api/messages/conversations');
    return (r?['conversations'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<int> getUnreadMessageCount() async {
    final r = await _get('/api/messages/unread');
    return r?['count'] ?? 0;
  }

  static Future<List<JSONObject>> getMessages(String userId) async {
    final r = await _get('/api/messages/$userId');
    return (r?['messages'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<JSONObject?> sendMessage(String userId, String content) => _post('/api/messages/$userId', {'content': content});

  // Groups
  static Future<JSONObject?> createGroup(String name, List<String> memberIds) => _post('/api/groups', {'name': name, 'memberIds': memberIds});
  static Future<List<JSONObject>> getGroups() async {
    final r = await _get('/api/groups');
    return (r?['groups'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<JSONObject?> getGroup(String groupId) => _get('/api/groups/$groupId');
  static Future<List<JSONObject>> getGroupMessages(String groupId) async {
    final r = await _get('/api/groups/$groupId/messages');
    return (r?['messages'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<JSONObject?> sendGroupMessage(String groupId, String content) => _post('/api/groups/$groupId/messages', {'content': content});
  static Future<JSONObject?> addGroupMembers(String groupId, List<String> userIds) => _post('/api/groups/$groupId/members', {'userIds': userIds});

  // Friends
  static Future<JSONObject?> sendFriendRequest(String userId) => _post('/api/friends/$userId', {});
  static Future<JSONObject?> getFriendStatus(String userId) => _get('/api/friends/status/$userId');
  static Future<List<JSONObject>> getPendingRequests() async {
    final r = await _get('/api/friends/pending');
    return (r?['requests'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<List<JSONObject>> getFriends() async {
    final r = await _get('/api/friends/friends');
    return (r?['friends'] as List?)?.cast<JSONObject>() ?? [];
  }

  static Future<JSONObject?> acceptFriendRequest(String requestId) => _put('/api/friends/$requestId/accept', {});
  static Future<JSONObject?> declineFriendRequest(String requestId) => _put('/api/friends/$requestId/decline', {});
  static Future<JSONObject?> removeFriend(String userId) => _delete('/api/friends/$userId');

  // Bookmarks
  static Future<JSONObject?> bookmarkPost(String postId) => _post('/api/posts/$postId/bookmark', {});
  static Future<JSONObject?> unbookmarkPost(String postId) => _delete('/api/posts/$postId/bookmark');
  static Future<List<JSONObject>> getBookmarks({int page = 1}) async {
    final r = await _get('/api/posts/bookmarks?page=$page');
    return (r?['posts'] as List?)?.cast<JSONObject>() ?? [];
  }

  // Password
  static Future<JSONObject?> changePassword(String oldPassword, String newPassword) => _put('/api/auth/password', {'oldPassword': oldPassword, 'newPassword': newPassword});

  // Search
  static Future<JSONObject?> search(String query) => _get('/api/search?q=${Uri.encodeComponent(query)}');
  static Future<JSONObject?> getTrends() => _get('/api/search/trends');

  // AI
  static Future<List<String>> fetchModels(String apiBase, String apiKey) async {
    try {
      final url = '$baseUrl/api/ai/models?apiBase=${Uri.encodeComponent(apiBase)}&apiKey=${Uri.encodeComponent(apiKey)}';
      final resp = await http.get(Uri.parse(url), headers: _headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['models'] as List?)?.cast<String>() ?? [];
      }
      return [];
    } catch (_) { return []; }
  }

  static Stream<String> chatStream({
    required List<Map<String, dynamic>> messages,
    required String apiBase,
    required String apiKey,
    required String model,
    required bool enableThinking,
  }) async* {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse('$baseUrl/api/ai'));
    request.headers.addAll(_headers);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'messages': messages,
      'apiBase': apiBase,
      'apiKey': apiKey,
      'model': model,
      'enableThinking': enableThinking,
    });

    final response = await client.send(request);
    final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]?['delta'];
          final content = delta?['content']?.toString() ?? '';
          final reasoning = delta?['reasoning_content']?.toString() ?? '';
          if (content.isNotEmpty && content != 'null') yield content;
          else if (reasoning.isNotEmpty && reasoning != 'null') yield '§REASONING§$reasoning';
        } catch (_) {}
      }
    }
    client.close();
  }

  // Upload
  static Future<String?> uploadFile(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
      request.headers['Authorization'] = 'Bearer ${_token ?? ""}';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        return data['url'];
      }
      return null;
    } catch (_) { return null; }
  }

  static Future<Map<String, String?>?> uploadFileWithThumbnail(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
      request.headers['Authorization'] = 'Bearer ${_token ?? ""}';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        return {'url': data['url'], 'thumbnail': data['thumbnail']};
      }
      return null;
    } catch (_) { return null; }
  }

  // Notifications
  static Future<List<JSONObject>> getNotifications() async {
    final r = await _get('/api/notifications');
    return (r?['notifications'] as List?)?.cast<JSONObject>() ?? [];
  }

  // Update check
  static Future<JSONObject?> checkUpdate(String version) async {
    return _get('/api/version?version=$version');
  }

  static Future<void> markAllRead() async {
    await _put('/api/notifications/read-all', {});
  }

  static Future<int> getUnreadCount() async {
    final r = await _get('/api/notifications/unread');
    return r?['count'] ?? 0;
  }
}

typedef JSONObject = Map<String, dynamic>;
