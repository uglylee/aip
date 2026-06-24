import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/provider_model.dart';
import 'providers_screen.dart';
import 'roles_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<AIProvider> providers = [];
  String currentProviderId = 'agnes';
  String selectedModel = '';
  bool enableThinking = true;
  bool saved = false;
  List<String> models = [];
  bool loadingModels = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    providers = await AIProvider.loadAll();
    currentProviderId = prefs.getString('current_provider_id') ?? 'agnes';
    final cp = providers.firstWhere((p) => p.id == currentProviderId, orElse: () => providers.first);
    selectedModel = prefs.getString('model_$currentProviderId') ?? cp.model;
    enableThinking = prefs.getBool('enable_thinking') ?? true;
    setState(() {});
  }

  AIProvider get currentProvider => providers.firstWhere((p) => p.id == currentProviderId, orElse: () => providers.first);

  void _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_provider_id', currentProviderId);
    await prefs.setString('model_$currentProviderId', selectedModel);
    await prefs.setBool('enable_thinking', enableThinking);
    setState(() => saved = true);
  }

  void _fetchModels() async {
    setState(() => loadingModels = true);
    final result = await ApiService.fetchModels(currentProvider.apiBase, currentProvider.apiKey);
    setState(() { models = result; loadingModels = false; });
  }

  @override
  Widget build(BuildContext context) {
    final maskedKey = currentProvider.apiKey.isNotEmpty
        ? '${currentProvider.apiKey.substring(0, [8, currentProvider.apiKey.length].reduce((a,b)=>a<b?a:b))}****'
        : '未设置';

    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (saved) ...[
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
              child: const Text('设置已保存', style: TextStyle(color: Colors.green))),
            const SizedBox(height: 12),
          ],
          // Providers section
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('供应商', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProvidersScreen())).then((_) => _load()),
              icon: const Icon(Icons.store, size: 18), label: const Text('管理')),
          ]),
          ...providers.map((p) {
            final savedModel = p.id == currentProviderId ? selectedModel : p.model;
            return Card(
              child: ListTile(
                title: Row(children: [
                  Text(p.name, style: TextStyle(fontWeight: currentProviderId == p.id ? FontWeight.bold : FontWeight.normal)),
                  if (currentProviderId == p.id) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, size: 16, color: Color(0xFF1DA1F2))],
                ]),
                subtitle: Text('模型: $savedModel'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  setState(() {
                    currentProviderId = p.id;
                    selectedModel = prefs.getString('model_${p.id}') ?? p.model;
                    models = [];
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          // Current provider details
          Text('当前: ${currentProvider.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(currentProvider.apiBase, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text('Key: $maskedKey', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          // Model selection
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('选择模型', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(onPressed: _fetchModels, icon: loadingModels ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 16), label: const Text('获取可用模型')),
          ]),
          DropdownButton<String>(
            value: models.contains(selectedModel) ? selectedModel : null,
            isExpanded: true,
            hint: Text(selectedModel),
            items: models.isEmpty
                ? [DropdownMenuItem(value: selectedModel, child: Text(selectedModel))]
                : models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) { if (v != null) setState(() { selectedModel = v; saved = false; }); },
          ),
          const SizedBox(height: 16),
          // Thinking toggle
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('启用 Thinking 模式'),
            Switch(value: enableThinking, onChanged: (v) => setState(() { enableThinking = v; saved = false; })),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('保存设置'))),
        ],
      ),
    );
  }
}
