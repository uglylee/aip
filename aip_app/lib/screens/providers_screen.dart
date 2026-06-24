import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/provider_model.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});
  @override State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  List<AIProvider> providers = [];
  String currentProviderId = 'agnes';
  bool testing = false;
  String testResult = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    providers = await AIProvider.loadAll();
    currentProviderId = prefs.getString('current_provider_id') ?? 'agnes';
    setState(() {});
  }

  void _test(AIProvider p) async {
    setState(() { testing = true; testResult = ''; });
    final models = await ApiService.fetchModels(p.apiBase, p.apiKey);
    setState(() {
      testing = false;
      testResult = models.isNotEmpty ? '${p.name} 连通成功 (${models.length} 个模型)' : '${p.name} 连通失败';
    });
  }

  void _showAddDialog({AIProvider? edit}) {
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final apiBaseCtrl = TextEditingController(text: edit?.apiBase ?? '');
    final apiKeyCtrl = TextEditingController(text: edit?.apiKey ?? '');
    final modelCtrl = TextEditingController(text: edit?.model ?? '');
    bool showKey = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(edit != null ? '编辑供应商' : '添加供应商'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 8),
              TextField(controller: apiBaseCtrl, decoration: const InputDecoration(labelText: 'API 地址')),
              const SizedBox(height: 8),
              TextField(controller: apiKeyCtrl, obscureText: !showKey, decoration: InputDecoration(
                labelText: 'API Key',
                suffixIcon: IconButton(icon: Icon(showKey ? Icons.visibility_off : Icons.visibility), onPressed: () => setDialogState(() => showKey = !showKey)),
              )),
              const SizedBox(height: 8),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: '默认模型')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(onPressed: () {
              if (nameCtrl.text.isNotEmpty && apiBaseCtrl.text.isNotEmpty) {
                final id = edit?.id ?? 'provider_${DateTime.now().millisecondsSinceEpoch}';
                final p = AIProvider(id: id, name: nameCtrl.text, apiBase: apiBaseCtrl.text, apiKey: apiKeyCtrl.text, model: modelCtrl.text);
                if (edit != null) {
                  providers = providers.map((x) => x.id == edit.id ? p : x).toList();
                } else {
                  providers = [...providers, p];
                }
                AIProvider.saveAll(providers);
                Navigator.pop(ctx);
                setState(() {});
              }
            }, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('供应商管理'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddDialog())],
      ),
      body: ListView(
        children: [
          if (testResult.isNotEmpty)
            Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(
              color: testResult.contains('成功') ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ), child: Text(testResult, style: TextStyle(color: testResult.contains('成功') ? Colors.green[800] : Colors.red[800]))),
          ...providers.map((p) => Card(
            child: ListTile(
              title: Row(children: [
                Text(p.name, style: TextStyle(fontWeight: currentProviderId == p.id ? FontWeight.bold : FontWeight.normal)),
                if (currentProviderId == p.id) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle, size: 16, color: Color(0xFF1DA1F2))),
              ]),
              subtitle: Text('模型: ${p.model}\nKey: ${p.apiKey.isNotEmpty ? p.apiKey.substring(0, [8, p.apiKey.length].reduce((a,b)=>a<b?a:b)) + '****' : "未设置"}'),
              isThreeLine: true,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (testing) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else IconButton(icon: const Icon(Icons.wifi_find, size: 20), onPressed: () => _test(p)),
                if (p.deletable)
                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.grey), onPressed: () {
                    providers = providers.where((x) => x.id != p.id).toList();
                    AIProvider.saveAll(providers);
                    setState(() {});
                  }),
              ]),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                setState(() { currentProviderId = p.id; });
                await prefs.setString('current_provider_id', p.id);
              },
            ),
          )),
        ],
      ),
    );
  }
}
