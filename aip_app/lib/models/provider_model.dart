import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AIProvider {
  final String id, name, apiBase, apiKey, model;
  final bool deletable;
  AIProvider({required this.id, required this.name, required this.apiBase, required this.apiKey, required this.model, this.deletable = true});

  factory AIProvider.fromJson(Map<String, dynamic> j) => AIProvider(
    id: j['id'] ?? '', name: j['name'] ?? '', apiBase: j['apiBase'] ?? '',
    apiKey: j['apiKey'] ?? '', model: j['model'] ?? '', deletable: j['deletable'] ?? true,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'apiBase': apiBase, 'apiKey': apiKey, 'model': model, 'deletable': deletable};

  static Future<List<AIProvider>> defaults() async {
    try {
      final resp = await http.get(Uri.parse('${ApiService.baseUrl}/api/default-provider'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return [AIProvider.fromJson({...data, 'deletable': false})];
      }
    } catch (_) {}
    return [AIProvider(id: 'agnes', name: 'Agnes AI', apiBase: 'https://apihub.agnes-ai.com/v1/chat/completions', apiKey: '', model: 'agnes-2.0-flash', deletable: false)];
  }

  static Future<List<AIProvider>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('providers');
    final defaults_ = await defaults();
    if (str != null) {
      try {
        final list = (jsonDecode(str) as List).map((e) => AIProvider.fromJson(e)).toList();
        final merged = <AIProvider>[...defaults_];
        for (final l in list) {
          if (!defaults_.any((d) => d.id == l.id)) merged.add(l);
          else {
            final idx = merged.indexWhere((d) => d.id == l.id);
            if (idx >= 0 && l.apiKey.isNotEmpty) merged[idx] = merged[idx].copyWith(apiKey: l.apiKey);
          }
        }
        return merged;
      } catch (_) {}
    }
    return defaults_;
  }

  static Future<void> saveAll(List<AIProvider> providers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('providers', jsonEncode(providers.map((e) => e.toJson()).toList()));
  }

  AIProvider copyWith({String? apiKey, String? model}) => AIProvider(
    id: id, name: name, apiBase: apiBase, apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model, deletable: deletable,
  );
}
