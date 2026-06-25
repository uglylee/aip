import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AIProvider {
  final String id, name, apiBase, apiKey, model;
  final bool deletable;
  AIProvider({required this.id, required this.name, required this.apiBase, required this.apiKey, required this.model, this.deletable = true});

  factory AIProvider.fromJson(Map<String, dynamic> j) => AIProvider(
    id: j['id'] ?? '', name: j['name'] ?? '', apiBase: j['apiBase'] ?? '',
    apiKey: j['apiKey'] ?? '', model: j['model'] ?? '', deletable: j['deletable'] ?? true,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'apiBase': apiBase, 'apiKey': apiKey, 'model': model, 'deletable': deletable};

  static List<AIProvider> defaults() => [
    AIProvider(id: 'agnes', name: 'Agnes AI', apiBase: 'https://apihub.agnes-ai.com/v1/chat/completions', apiKey: '', model: 'agnes-2.0-flash', deletable: false),
  ];

  static Future<List<AIProvider>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('providers');
    if (str != null) {
      try {
        final list = (jsonDecode(str) as List).map((e) => AIProvider.fromJson(e)).toList();
        final defaults_ = defaults();
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
    return defaults();
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
