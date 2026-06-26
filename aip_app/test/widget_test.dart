import 'package:flutter_test/flutter_test.dart';
import 'package:aip_app/models/user.dart';
import 'package:aip_app/models/post.dart';
import 'package:aip_app/models/message.dart';
import 'package:aip_app/models/provider_model.dart';
import 'package:aip_app/models/role.dart';

void main() {
  group('User model', () {
    test('fromJson with id field', () {
      final u = User.fromJson({
        'id': 'abc123',
        'username': 'Alice',
        'handle': 'alice',
        'avatar': 'ava.png',
        'bio': 'Hello',
        'followers': 10,
        'following': 5,
        'isFollowing': true,
      });
      expect(u.id, 'abc123');
      expect(u.username, 'Alice');
      expect(u.handle, 'alice');
      expect(u.avatar, 'ava.png');
      expect(u.bio, 'Hello');
      expect(u.followers, 10);
      expect(u.following, 5);
      expect(u.isFollowing, true);
    });

    test('fromJson with _id field (MongoDB)', () {
      final u = User.fromJson({
        '_id': 'mongo123',
        'username': 'Bob',
        'handle': 'bob',
      });
      expect(u.id, 'mongo123');
      expect(u.username, 'Bob');
    });

    test('fromJson with missing fields uses defaults', () {
      final u = User.fromJson({});
      expect(u.id, '');
      expect(u.username, '');
      expect(u.handle, '');
      expect(u.avatar, '');
      expect(u.bio, '');
      expect(u.followers, 0);
      expect(u.following, 0);
      expect(u.isFollowing, false);
    });

    test('fromJson with followers as list', () {
      final u = User.fromJson({
        'id': 'x',
        'followers': ['a', 'b', 'c'],
      });
      expect(u.followers, 3);
    });

    test('fromJson prefers id over _id', () {
      final u = User.fromJson({'id': 'id_val', '_id': 'underscore_val'});
      expect(u.id, 'id_val');
    });
  });

  group('Post model', () {
    test('fromJson with id field', () {
      final p = Post.fromJson({
        'id': 'post1',
        'content': 'Hello world',
        'createdAt': '2024-01-01',
        'author': {'id': 'u1', 'username': 'A', 'handle': 'a'},
        'images': ['img1.jpg'],
        'videos': ['vid1.mp4'],
        'thumbnails': ['thumb1.jpg'],
        'likes': ['u1', 'u2'],
        'retweets': ['u3'],
        'viewCount': 42,
        'replyCount': 3,
      });
      expect(p.id, 'post1');
      expect(p.content, 'Hello world');
      expect(p.author?.username, 'A');
      expect(p.images, ['img1.jpg']);
      expect(p.videos, ['vid1.mp4']);
      expect(p.likes, 2);
      expect(p.retweets, 1);
      expect(p.viewCount, 42);
      expect(p.replyCount, 3);
    });

    test('fromJson with _id field', () {
      final p = Post.fromJson({
        '_id': 'mongo_post',
        'content': 'Test',
        'createdAt': '2024-01-01',
      });
      expect(p.id, 'mongo_post');
    });

    test('fromJson empty/null fields', () {
      final p = Post.fromJson({});
      expect(p.id, '');
      expect(p.content, '');
      expect(p.images, []);
      expect(p.videos, []);
      expect(p.likes, 0);
    });

    test('fromJson null author', () {
      final p = Post.fromJson({'id': 'p1', 'content': 'x', 'createdAt': ''});
      expect(p.author, isNull);
    });
  });

  group('ChatMessage model', () {
    test('fromJson with id', () {
      final m = ChatMessage.fromJson({
        'id': 'msg1',
        'sender': 'u1',
        'content': 'Hi',
        'createdAt': '2024-01-01',
      });
      expect(m.id, 'msg1');
      expect(m.sender, 'u1');
      expect(m.content, 'Hi');
    });

    test('fromJson with _id', () {
      final m = ChatMessage.fromJson({
        '_id': 'mongo_msg',
        'sender': 'u2',
        'content': 'Hey',
        'createdAt': '2024-01-02',
      });
      expect(m.id, 'mongo_msg');
    });

    test('fromJson defaults', () {
      final m = ChatMessage.fromJson({});
      expect(m.id, '');
      expect(m.sender, '');
      expect(m.content, '');
    });
  });

  group('AIProvider model', () {
    test('fromJson', () {
      final p = AIProvider.fromJson({
        'id': 'deepseek',
        'name': 'DeepSeek',
        'apiBase': 'https://api.deepseek.com',
        'apiKey': 'sk-xxx',
        'model': 'deepseek-chat',
        'deletable': true,
      });
      expect(p.id, 'deepseek');
      expect(p.name, 'DeepSeek');
      expect(p.apiKey, 'sk-xxx');
    });

    test('toJson round-trip', () {
      final original = AIProvider(
        id: 'test',
        name: 'Test',
        apiBase: 'https://test.com',
        apiKey: 'key',
        model: 'm',
        deletable: false,
      );
      final json = original.toJson();
      final restored = AIProvider.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.apiBase, original.apiBase);
      expect(restored.apiKey, original.apiKey);
      expect(restored.deletable, original.deletable);
    });

    test('copyWith', () {
      final p = AIProvider(
        id: 'x', name: 'X', apiBase: 'url', apiKey: 'old', model: 'm',
      );
      final p2 = p.copyWith(apiKey: 'new', model: 'm2');
      expect(p2.apiKey, 'new');
      expect(p2.model, 'm2');
      expect(p2.id, 'x');
    });

    test('defaults returns agnes', () async {
      final defs = await AIProvider.defaults();
      expect(defs.length, 1);
      expect(defs[0].id, 'agnes');
      expect(defs[0].deletable, false);
    });
  });

  group('Role model', () {
    test('defaults', () {
      final defs = Role.defaults();
      expect(defs.length, 2);
      expect(defs[0].id, 'default');
      expect(defs[0].deletable, false);
      expect(defs[1].id, 'translator');
      expect(defs[1].systemPrompt.contains('翻译'), true);
      expect(defs[1].deletable, false);
    });

    test('custom role', () {
      final r = Role(id: 'custom', name: 'Bot', systemPrompt: 'You are a bot');
      expect(r.id, 'custom');
      expect(r.deletable, true);
    });
  });
}
